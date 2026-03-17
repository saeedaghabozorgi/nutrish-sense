import os
import asyncio
import vertexai
from google.adk.agents import LlmAgent
from google.adk.runners import InMemoryRunner
from google.genai.types import Part, UserContent

os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
vertexai.init(project="saeed-demo-proj", location="us-central1")

agent = LlmAgent(
    name="chief_agent",
    model="gemini-3-flash-preview",
    instruction="Act as an expert car mechanic. Tell me what is wrong with this vehicle."
)

async def main():
    runner = InMemoryRunner(agent=agent)
    session = await runner.session_service.create_session(app_name=runner.app_name, user_id="app_user")
    user_input = UserContent(parts=[Part.from_text(text="My car makes a loud grinding noise when I brake.")])
    
    result = ""
    async for event in runner.run_async(user_id=session.user_id, session_id=session.id, new_message=user_input):
        if getattr(event, 'content', None) and event.content.parts:
            result = event.content.parts[0].text
    print("Mechanic Response:", result)

asyncio.run(main())
