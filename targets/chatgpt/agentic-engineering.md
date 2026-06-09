---
name: agentic-engineering
description: >
  Use this skill when building with Claude API, Anthropic SDK, or managed agents. Covers model selection, cost-conscious patterns, token budgeting, batch processing, prompt caching, and cost tracking for LLM-driven applications.
---

# Agentic engineering

Build with Claude API and managed agents. Focus: cost awareness, right-size models, sustainable LLM workflows.

## Model selection

Pick by task complexity, cost, and latency. Model names, prices, and discount rates change — verify current details in official Anthropic docs before quoting costs or hard-coding model IDs.

| Tier                        | Best for                                                                    | Trade-off                                       |
| --------------------------- | --------------------------------------------------------------------------- | ----------------------------------------------- |
| **Largest reasoning model** | Complex reasoning, multi-step planning, code generation, research synthesis | Highest quality, highest cost and latency       |
| **Balanced model**          | Most LLM tasks, general purpose work, fast iteration                        | Strong default for quality and cost             |
| **Fast model**              | Simple tasks, high-volume processing, real-time responses                   | Lowest latency and cost, weaker on complex work |

### Selection heuristics

- **Use the fast model** for: bulk text classification, simple summaries, content filtering, high-frequency tasks (chatbots, API responses)
- **Use the balanced model** for: default — feature work, debugging, code review, most agent tasks
- **Use the largest reasoning model** when the balanced model fails or the task needs deep reasoning — multi-doc synthesis, architectural decisions, complex proofs

### Cost-quality trade-off

Test on the fastest suitable model first. Underperforms → upgrade to the balanced model. Only use the largest reasoning model if the balanced model consistently fails.

```python
# Example: classify sentiment
def classify_sentiment(text: str) -> str:
    response = client.messages.create(
        model="claude-haiku-4-5",  # verify current model ID before shipping
        max_tokens=50,
        messages=[{"role": "user", "content": f"Classify sentiment: {text}. Reply: positive, negative, or neutral."}]
    )
    return response.content[0].text
```

## Token budgeting

Tokens = cost unit. Manage three categories:

### Input tokens (cheaper)

- Every prompt word costs
- Long contexts (system prompts, documents, examples) multiply input cost
- Caching: repeat inputs amortise cost over time

### Output tokens (more expensive)

- Longer responses cost more
- Step-by-step reasoning uses 2–3× more tokens than direct answers
- Use `max_tokens` to cap runaway outputs

For batch processing, prompt caching, cost tracking, structured output, streaming, managed agents, and monitoring, see [references/cost-patterns.md](references/cost-patterns.md).
