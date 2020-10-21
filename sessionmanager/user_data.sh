#!/bin/sh
# docker install
amazon-linux-extras install -y docker
systemctl start docker
systemctl enable docker