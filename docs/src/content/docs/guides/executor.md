---
title: executor
description: 'Learn about the command executor'
---

Mamba

## Create executor

The create executor writes command output to standard output. It reports
failures to standard error and marks the process as failed. It also runs
post-hooks after a command finishes.

```mermaid
flowchart TD
    A["Receive command-line arguments"] --> B["Apply default command paths"]
    B --> C["Validate the command path and inputs"]
    C --> D{"Show help or run a command?"}

    D -->|Show help| E["Format and write help"]
    D -->|Run command| F["Create a read-only command context"]
    F --> G["Run persistent pre-hooks<br/>from outer group to inner group"]
    G --> H{"Does the command use hooks?"}
    H -->|Yes| I["Read piped standard input<br/>and run the pre-hook"]
    H -->|No| J["Run the selected command"]
    I --> J
    J --> K["Write command output when present"]
    K --> L["Run the command post-hook"]
    L --> M["Run persistent post-hooks<br/>from inner group to outer group"]

    C -. "Validation failure" .-> N["Write the failure to standard error<br/>and mark the process as failed"]
    G -. "Hook or command failure" .-> N
    L -. "Post-hook failure" .-> N
```

## Fake executor

The fake executor follows the same selection, validation, and pre-hook flow,
but returns a result for the test to inspect. It never writes to process streams
and does not run post-hooks.

```mermaid
flowchart TD
    A["Receive test arguments"] --> B["Apply default command paths"]
    B --> C["Validate the command path and inputs"]
    C --> D{"Show help or run a command?"}

    D -->|Show help| E["Return formatted help as a success result"]
    D -->|Run command| F["Create a read-only command context"]
    F --> G["Run persistent pre-hooks<br/>from outer group to inner group"]
    G --> H{"Does the command use hooks?"}
    H -->|Yes| I["Read piped standard input<br/>and run the pre-hook"]
    H -->|No| J["Run the selected command"]
    I --> J
    J --> K["Return command output as a success result"]

    C -. "Validation failure" .-> L["Return a failure result"]
    G -. "Hook or command failure" .-> L

    M["Do not run command or persistent post-hooks"]
    K -.-> M
    E -.-> M
```
