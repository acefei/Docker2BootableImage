#!/usr/bin/python3

"""
Build an XVA using the new XVA format (version 2)
"""

import logging
import os
from argparse import ArgumentParser
from errno import ENXIO
from hashlib import sha1
from math import ceil
from pathlib import Path
from string import Template
from subprocess import check_call
from tempfile import TemporaryDirectory


def copy_and_hash(fin, fout, start, to_copy):
    sha = sha1()
    fin.seek(start)
    buf_size = 1024 * 1024
    while to_copy > 0:
        data = fin.read(min(buf_size, to_copy))
        if not data:
            break  # end of file
        sha.update(data)
        fout.write(data)
        to_copy -= len(data)
    return sha.hexdigest()


def get_next_data_segment(fin, from_pos):
    """
    Uses SEEK_DATA and SEEK_HOLE to discover the sparseness, should be run on a filesystem on which these are efficient.
    """
    try:
        data_start = os.lseek(fin.fileno(), from_pos, os.SEEK_DATA)
    except OSError as error:
        if error.errno == ENXIO:
            # No more data after pos
            return None
        raise
    # This should always succeed because there is a virtual hole at
    # the end of the file
    data_end = os.lseek(fin.fileno(), data_start, os.SEEK_HOLE) - 1
    logging.debug(f"found data: bytes {data_start}-{data_end}")
    return (data_start, data_end)


def get_nonempty_chunks(fin, chunk_size):
    pos = 0
    while True:
        data = get_next_data_segment(fin, pos)
        if not data:
            break
        (data_start, data_end) = data
        chunk_start = int(data_start / chunk_size)
        chunk_end = int(data_end / chunk_size)
        for chunk in range(chunk_start, chunk_end + 1):
            yield chunk
        pos = (chunk_end + 1) * chunk_size


def chunk_img(img, output_dir, chunk_size=1024 * 1024):
    os.makedirs(output_dir, exist_ok=True)
    size = os.path.getsize(img)

    with open(img, "rb") as fin:

        def write_chunk(chunk_no):
            logging.debug(f"{output_dir}: writing chunk {chunk_no}")
            chunk_file = os.path.join(output_dir, "{0:020d}".format(chunk_no))
            with open(chunk_file, "wb+") as out:
                chunk_start = chunk_no * chunk_size
                file_hash = copy_and_hash(fin, out, chunk_start, chunk_size)
            checksum_file = os.path.join(
                output_dir, "{0:020d}.checksum".format(chunk_no)
            )
            with open(checksum_file, "w+") as out:
                out.write(file_hash)

        # We have to save the first block
        write_chunk(0)
        # And we have to save the last block
        last_chunk = int(ceil(size / chunk_size)) - 1
        if last_chunk > 0:
            write_chunk(last_chunk)

        for chunk in get_nonempty_chunks(fin, chunk_size):
            if chunk > 0 and chunk < last_chunk:
                write_chunk(chunk)

    chunk_list = sorted(os.path.join(output_dir, f) for f in os.listdir(output_dir))
    return (size, chunk_list)


def _produce_parser():
    parser = ArgumentParser(description="Create an XVA from a sparse file. ")
    parser.add_argument("image", help="Path of Raw image")
    parser.add_argument(
        "-c", "--cpus", type=int, default=2, help="CPU Number of VM. Default is 2"
    )
    parser.add_argument(
        "-m", "--memory", type=int, default=4, help="Memory Size of VM. Default is 4GB"
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="Enable verbose mode for debuging"
    )
    return parser


def main():
    settings = _produce_parser().parse_args()
    log_level = logging.DEBUG if settings.verbose else logging.INFO
    logging.basicConfig(level=log_level, format=("[%(levelname)s] %(message)s"))
    script_dir = Path(__file__).resolve().parent
    image_path = settings.image
    image_name = Path(image_path).stem

    with TemporaryDirectory() as tempdir:
        root_vdi_ref = "Ref:VDI-1-root"
        logging.info(f"Chunking {image_path}...")
        (root_size_bytes, root_chunks) = chunk_img(
            img=image_path, output_dir=f"{tempdir}/{root_vdi_ref}"
        )

        config = {
            # vm name with random string suffix
            "vm_name_label": f"{image_name}-{tempdir[8:]}",
            "vm_name_description": image_name,
            "memory_bytes": settings.memory * 1024 * 1024 * 1024,
            "vcpus": settings.cpus,
            "root_vdi_virtual_size_bytes": root_size_bytes,
            "root_vdi_ref": root_vdi_ref,
        }

        ova_xml_path = f"{tempdir}/ova.xml"
        logging.info(f"Populating {ova_xml_path}...")
        with open(f"{script_dir}/ova.xml.in", "r") as fin, open(
            ova_xml_path, "w"
        ) as fout:
            ova = Template(fin.read())
            fout.write(ova.substitute(config))

        xva_path = f"{script_dir}/{image_name}.xva"
        logging.info(f"Creating {xva_path}...")
        check_call(
            ["tar", "zchfP", xva_path, "--transform", f"s~{tempdir}/~~", ova_xml_path]
            + root_chunks
        )


if __name__ == "__main__":
    main()
