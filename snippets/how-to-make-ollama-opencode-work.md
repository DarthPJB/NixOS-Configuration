```
ollama run qwen2.5-coder:7b
>>> /set parameter num_ctx 16384
>>> /save qwen2.5:7b-16k
>>> /bye
```

and in opencode.json
```
 "models": {
        "qwen2.5:7b-16k": {
          "name": "qwen2.5",
          "tool_call": true,
          "limit": {
            "context": 16384,
            "output": 8192
          }
        },
        "qwen2.5-coder:7b": {
          "name": "qwen2.5-coder",
          "tool_call": true,
          "limit": {
            "context": 16384,
            "output": 8192
          }
        }
```

NOTE THE ALIAS: "qwen2.5:7b-16k"
