import asyncio
import os
import vertexai
from google.adk.agents import LlmAgent
from vertexai.agent_engines import AdkApp
from google.genai.types import Part, UserContent

os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
vertexai.init(project="saeed-demo-proj", location="us-central1")

agent = LlmAgent(
    name="chief_agent",
    model="gemini-2.5-flash",
    instruction="Analyze the image."
)

app = AdkApp(agent=agent)

async def test():
    user_input = {
        "parts": [
            {"file_data": {"file_uri": "gs://saeed-demo-proj.firebasestorage.app/photos/euuK9uowLNd134saFlexiG3zu9b2/1773667113527.jpg", "mime_type": "image/jpeg"}},
            {"text": "Analyze this image for a patient with Gout."}
        ]
    }
    
    # Try passing multimodal dictionary
    try:
        async for event in app.async_stream_query(
            user_id="test-user",
            message=user_input
        ):
            print("EVENT:", event)
            if 'content' in event and 'parts' in event['content']:
                print(event['content']['parts'])
    except Exception as e:
        print("Error with dict input:", e)

asyncio.run(test())
