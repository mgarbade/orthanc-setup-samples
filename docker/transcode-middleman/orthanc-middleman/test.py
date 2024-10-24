print("# HELLO FROM PYTHON")

import orthanc
import json

# Callback function to handle new DICOM instances
def on_new_instance(change_type, level, resource):
    if change_type == orthanc.ChangeType.NEW_INSTANCE:
        print(f"# PYTHON HERE: New DICOM instance received: {resource}")

        # Fetch the metadata of the new instance
        metadata = orthanc.RestApiGet(f"/instances/{resource}/tags")
        dicom_info = json.loads(metadata)

        # Extract and log patient ID and study date as an example
        patient_id = dicom_info.get("0010,0020", {}).get("Value", ["Unknown"])[0]
        study_date = dicom_info.get("0008,0020", {}).get("Value", ["Unknown"])[0]
        print(f"# PYTHON HERE: Patient ID: {patient_id}, Study Date: {study_date}")

        # Save the metadata to a file
        with open(f"/path/to/logs/{resource}_info.json", "w") as file:
            json.dump(dicom_info, file, indent=4)
    
    elif change_type == orthanc.ChangeType.ORTHANC_STARTED:
        print("# PYTHON HERE: Orthanc started and is ready to process DICOM files.")

# Register the callback
orthanc.RegisterOnChangeCallback(on_new_instance)
