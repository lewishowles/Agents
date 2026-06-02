# Agentic engineering — cost patterns

## Batch processing

Use the batch API for non-urgent, high-volume work (bulk classification, summaries, reports). ~24-hour processing window; verify current discount rate against official Anthropic pricing.

```python
batch_input_file_id = client.beta.files.upload(file=open("requests.jsonl", "rb")).id

batch = client.beta.messages.batches.create(
    requests=[
        {
            "custom_id": "request-1",
            "params": {
                "model": "claude-sonnet-4-6",
                "max_tokens": 1024,
                "messages": [{"role": "user", "content": "Classify: ..."}],
            },
        },
    ],
)
```

## Prompt caching

Cache static content (docs, examples, system prompts) across requests. Cache hits are cheaper and faster. Verify current rates before quoting savings.

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    system=[
        {
            "type": "text",
            "text": "You are a code reviewer...",
            "cache_control": {"type": "ephemeral"},
        }
    ],
    messages=[
        {
            "role": "user",
            "content": [
                {"type": "text", "text": "Here's the code:", "cache_control": {"type": "ephemeral"}},
                {"type": "text", "text": code_snippet},
            ],
        }
    ],
)
```

Monitor `usage.cache_read_input_tokens` vs `usage.input_tokens`. Target >30% cache reads on repeated tasks.

## Cost tracking

```python
def log_usage(response) -> None:
    usage = response.usage
    print(
        "Model: {model}; input: {input}; cache read: {cache}; output: {output}".format(
            model=response.model,
            input=usage.input_tokens,
            cache=getattr(usage, "cache_read_input_tokens", 0),
            output=usage.output_tokens,
        )
    )
```

Aggregate by model, task, and time period. Calculate cost from a central pricing table reviewed against official docs.

## Patterns for cost efficiency

### Few-shot examples over lengthy instructions

```python
# Bad: long explanation
system = "You are a classifier. Consider semantic meaning, context, domain-specific terminology..."

# Good: examples
system = """Classify into [positive, negative, neutral].

Example:
- "Love this!" → positive
- "Terrible." → negative
- "It's fine." → neutral"""
```

### Structured output (JSON schema)

Constrains output format, cuts token waste and parsing overhead:

```python
response = client.messages.create(
    model="claude-sonnet-4-6",
    max_tokens=1024,
    messages=[...],
    response_format={
        "type": "json_schema",
        "json_schema": {
            "name": "classification",
            "schema": {
                "type": "object",
                "properties": {
                    "label": {"type": "string", "enum": ["positive", "negative", "neutral"]},
                    "confidence": {"type": "number"},
                },
                "required": ["label", "confidence"],
            },
        },
    },
)
```

### Batch items in one request

```python
# Bad: N requests for N items
for text in texts:
    response = client.messages.create(model="claude-sonnet-4-6", max_tokens=50,
        messages=[{"role": "user", "content": f"Classify: {text}"}])

# Good: 1 request for N items
response = client.messages.create(model="claude-sonnet-4-6", max_tokens=500,
    messages=[{"role": "user", "content":
        "Classify each (reply in JSON):\n\n" + "\n".join(f"{i}: {t}" for i, t in enumerate(texts))}])
```

### Streaming for perceived performance

No cost reduction, but improves UX:

```python
with client.messages.stream(model="claude-sonnet-4-6", max_tokens=1024,
        messages=[{"role": "user", "content": "..."}]) as stream:
    for text in stream.text_stream:
        print(text, end="", flush=True)
```

## Managed agents

Use managed agents for complex, long-running tasks. They handle tool use, looping, and state automatically — no orchestration token overhead (managed server-side). Pay only for actual Claude API calls.

## Monitoring & observability

- Track API usage via Anthropic Dashboard
- Alert on unexpected cost spikes
- Log token usage per task, model, and user
- Publish monthly cost breakdown
- Benchmark cost per feature
