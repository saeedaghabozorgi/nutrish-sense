import asyncio
import os
import vertexai
from dietary_agent.agent import agent
from vertexai.genai import types

os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "true"
vertexai.init(project="saeed-demo-proj", location="us-central1")

async def run_test():
    print("Testing Multi-Agent orchestration...")
    
    # We will pass a dummy image string instead of real image for unit testing
    prompt = "I have diabetes and high blood pressure. I am taking amlodipine. I just ate a large triple cheeseburger with bacon and a large fries."
    
    response = await agent.async_execute(prompt)
    print("\n--- AGENT RESPONSE ---")
    print(response)

if __name__ == "__main__":
    asyncio.run(run_test())
