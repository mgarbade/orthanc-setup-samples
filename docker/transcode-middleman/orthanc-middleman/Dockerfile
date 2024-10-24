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
&& mkdir -p /path/to/store

# Change ownership and permissions for the store directory to ensure Orthanc can write to it
# Assuming Orthanc runs as the `orthanc` user; adjust if it runs as a different user
RUN chown -R orthanc:orthanc /path/to/store \
&& chmod -R 775 /path/to/store

# Copy configuration and script files
COPY orthanc.json /etc/orthanc/
COPY dicom_series_inference.lua /etc/share/orthanc/scripts/
