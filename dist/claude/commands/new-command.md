# New command

Scaffold a new slash command file.

## Steps

1. Determine the command name from `$ARGUMENTS`. Use kebab-case (e.g. `summarise-pr`, `fix-types`). If no name is given, ask for one.

2. Create the file at `.claude/commands/<name>.md` for a project command, or describe creating it at `~/.claude/commands/<name>.md` for a global command. Ask the user which scope they want if unclear.

3. Write the file using this structure:

```markdown
# <Command name>

<One sentence describing what this command does.>

## Steps

1. <First step>
2. <Second step>

## Considerations

- <Any relevant caveats, edge cases, or things to be aware of>
```

4. Use `$ARGUMENTS` in the steps where the user's input should be passed through — for example, referencing a branch name, file path, or search term they provide when invoking the command.

## Considerations

- Keep steps short and imperative — they are instructions to the model, not documentation for a human
- Only add a Considerations section if there are genuine caveats worth surfacing
- The file name becomes the slash command: `summarise-pr.md` → `/summarise-pr`
