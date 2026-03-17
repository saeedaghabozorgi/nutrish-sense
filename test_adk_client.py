import vertexai
from vertexai.preview.reasoning_engines import ReasoningEngine
import asyncio

async def test():
    vertexai.init(project="saeed-demo-proj", location="us-central1")
    engines = filter(
        lambda e: e.display_name and e.display_name.startswith("Multi-Agent ADK Dietician"),
        ReasoningEngine.list()
    )
    sorted_engines = sorted(list(engines), key=lambda x: x.create_time, reverse=True)
    if not sorted_engines:
        print("No engines found")
        return
        
    engine_id = sorted_engines[0].resource_name
    print(f"Using Engine: {engine_id}")
    
    client = vertexai.Client(project="saeed-demo-proj", location="us-central1")
    adk_app = client.agent_engines.get(name=engine_id)
    
    print("Schema Operations:")
    try:
        print(adk_app.operation_schemas())
    except Exception as e:
        print(f"Error calling operation_schemas(): {e}")

    print("Methods available on adk_app:")
    print([m for m in dir(adk_app) if not m.startswith('_')])

asyncio.run(test())
