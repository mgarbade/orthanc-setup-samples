FROM orthancteam/orthanc

# Update and install necessary packages
RUN apt-get update \
&& DEBIAN_FRONTEND=noninteractive apt-get -y install \
libgdcm-tools \
dcmtk \
apt-transport-https \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

# Create necessary directories
RUN mkdir -p /etc/share/orthanc/scripts \
&& mkdir -p /path/to/store \
&& mkdir -p /path/to/logs

# Change ownership and permissions for the store directory to ensure Orthanc can write to it
# Assuming Orthanc runs as the `orthanc` user; adjust if it runs as a different user
RUN chown -R orthanc:orthanc /path/to/store \
&& chmod -R 775 /path/to/store

# Copy configuration and script files
COPY orthanc.json /etc/orthanc/
COPY dicom_series_inference.lua /etc/share/orthanc/scripts/



# This example is using a virtual env that is not mandatory when using Docker containers
# but recommended since python 3.11 and Debian bookworm based images where you get a warning
# when installing system-wide packages.
RUN apt-get update && apt install -y python3-venv
RUN python3 -m venv /.venv

RUN /.venv/bin/pip install pydicom
ENV PYTHONPATH=/.venv/lib64/python3.11/site-packages/

RUN mkdir /python
COPY test.py /python/
COPY run_inference.py /python/
