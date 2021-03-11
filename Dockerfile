FROM centos:7.9.2009 AS base
RUN yum update -y \
    && yum install -y make \ 
                      grub2 \
                      libguestfs-tools \
    && yum clean all
