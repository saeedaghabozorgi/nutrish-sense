import asyncio
from typing import Annotated
from google.adk.agents import LlmAgent
from google.adk.tools import FunctionTool

def get_ingredient():
    return "Lettuce"

tool = FunctionTool(get_ingredient)
agent = LlmAgent(
    name="test",
    model="gemini-3-flash-preview",
    instruction="Extract ingredient and return valid JSON.",
    tools=[tool],
    output_schema={"type": "OBJECT", "properties": {"food": {"type": "STRING"}}}
)
from google.adk.runners import InMemoryRunner
from google.adk.models import UserContent, Part
async def main():
    runner = InMemoryRunner(agent=agent)
    session = await runner.session_service.create_session("app", "user")
    async for event in runner.run_async(session.user_id, session.id, UserContent(parts=[Part.from_text(text="What is the food?")])):
        if getattr(event, 'content', None) and event.content.parts:
            print("Response:", event.content.parts[0].text)

asyncio.run(main())
