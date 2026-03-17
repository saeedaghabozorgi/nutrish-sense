import asyncio
import json
import vertexai
import uuid

async def test():
    vertexai.init(project="saeed-demo-proj", location="us-central1")
    engine_id = "projects/941446881468/locations/us-central1/reasoningEngines/1161997973094137856"
    
    print("Connecting to live V8 engine:", engine_id)
    client = vertexai.Client(project="saeed-demo-proj", location="us-central1")
    adk_app = client.agent_engines.get(name=engine_id)
    
    prompt_msg = {
        "role": "user",
        "parts": [
            {"file_data": {"file_uri": "gs://saeed-demo-proj.firebasestorage.app/photos/euuK9uowLNd134saFlexiG3zu9b2/1773667113527.jpg", "mime_type": "image/jpeg"}},
            {"text": "Analyze this image for a patient with: Gout"}
        ]
    }
    
    uid = f"user_{str(uuid.uuid4())}"
    text_result = ""
    print("Streaming events...")
    async for event in adk_app.async_stream_query(
        user_id=uid,
        message=prompt_msg
    ):
        if 'content' in event and 'parts' in event['content']:
            for part in event['content']['parts']:
                if 'text' in part:
                    text_result += part['text']
                    
    print("\nFINAL TEXT:\n", text_result)

asyncio.run(test())
