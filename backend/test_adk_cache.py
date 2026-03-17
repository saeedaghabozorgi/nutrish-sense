import asyncio
from google.adk.runners import InMemoryRunner
from google.adk.agents import LlmAgent
from google.adk.models import UserContent, Part

agent = LlmAgent(name="test", model="gemini-3-flash-preview", instruction="You are a helpful assistant.")

async def run_query(prompt):
    runner = InMemoryRunner(agent=agent)
    session = await runner.session_service.create_session(user_id="app_user", app_name=runner.app_name)
    async for event in runner.run_async(user_id=session.user_id, session_id=session.id, new_message=UserContent(parts=[Part.from_text(text=prompt)])):
        if getattr(event, 'content', None) and event.content.parts:
            print("Response:", event.content.parts[0].text)

async def main():
    print("Call 1:")
    await run_query("Remember this secret: WATERMELON")
    print("Call 2:")
    await run_query("What was the secret?")

asyncio.run(main())
