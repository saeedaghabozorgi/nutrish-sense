import vertexai
import json

def test():
    vertexai.init(project="saeed-demo-proj", location="us-central1")
    engine_id = "projects/941446881468/locations/us-central1/reasoningEngines/2990459421806559232"
    
    client = vertexai.Client(project="saeed-demo-proj", location="us-central1")
    adk_app = client.agent_engines.get(name=engine_id)
    
    print("Calling using api_client.query()...")
    res = adk_app.api_client.query(
        engine_id, 
        image_uri="gs://saeed-demo-proj.firebasestorage.app/photos/euuK9uowLNd134saFlexiG3zu9b2/1773667113527.jpg",
        diseases="Gout"
    )
    print("Response:", res)
    
test()
