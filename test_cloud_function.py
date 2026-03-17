import urllib.request
import json

url = "https://us-central1-saeed-demo-proj.cloudfunctions.net/analyze_image"
data = {
    "data": {
        "gcs_uri": "gs://saeed-demo-proj.firebasestorage.app/photos/euuK9uowLNd134saFlexiG3zu9b2/1773667113527.jpg",
        "disease": "Gout, Hypertension",
        "labResults": "",
        "medications": "",
        "allergies": "",
        "activityLevel": 1.0
    }
}
req = urllib.request.Request(url, data=json.dumps(data).encode('utf-8'), headers={'Content-Type': 'application/json'})
try:
    with urllib.request.urlopen(req) as response:
        print(response.read().decode('utf-8'))
except Exception as e:
    print("Error:", e)
