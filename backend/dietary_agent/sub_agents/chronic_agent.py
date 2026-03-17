from google.adk import Agent

chronic_agent = Agent(
    name="chronic_agent",
    model="gemini-3-flash-preview",
    description="Tool to evaluate a specific medical condition against the ingredients extracted by the vision agent.",
    instruction="""
    Act as a highly specialized medical dietician.
    The user will ask you to evaluate a specific medical condition.
    Use the extracted Food Ingredients & Portion and the Patient Medical Context from the conversation history.
    Evaluate ONLY based on the requested condition.
    Output exactly valid JSON:
    {"color": "Green" or "Yellow" or "Red", "reasoning": "Detailed clinical reasoning."}
    Do not use markdown blocks.
    """,
    output_key="chronic_output"
)
