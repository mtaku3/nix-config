# Instructions

- Before handling every user request, you MUST call Supermemory `search_memory` with a query relevant to the request—even when no relevant memory seems likely. Do not provide a substantive response or take task actions until the search completes. Apply relevant results.
- If Supermemory is unavailable or the search fails, state that explicitly; never claim memories were checked when they were not.
- Save to Supermemory only durable, long-term information. Never save temporary task state.
- Never force-push.
