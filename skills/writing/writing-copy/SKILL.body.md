# UI copy

Microcopy = short interface text guiding action. Bar: clear in one read.

## Buttons and CTAs

- Lead with verb — `Save changes`, not `OK`
- Be specific about what happens — `Delete account` beats `Confirm`
- Match surrounding form: `Sign in` form → `Sign in` button, not `Submit`
- Icon-only buttons still need accessible name: `Close menu`, `Delete project`, `Copy link`

## Error messages

- Say what went wrong and what to do — `Password must be at least 8 characters`, not `Invalid password`
- Plain language; never expose stack traces or codes alone
- Don't blame user — `That email is already taken` not `You entered an invalid email`
- Inline errors should work with field label: `Enter an email address`, not `Email error`

## Empty states

- Acknowledge empty and point to next action — `No projects yet. Create one to get started.`
- Avoid placeholder text that looks like data — confuses screen readers and low-cognition users

## Confirmations

- Confirm with identifiable info — `User "Lewis Howles" deleted`, not `User deleted`
- Destructive actions: restate consequence — `Delete account? This removes 12 projects and can't be undone.`
- Prefer undo for reversible destructive actions. Use confirmation for hard-to-undo or high-impact actions

## Supporting text

- Place near related input; don't hide essential info in tooltips
- Keep short — more than two sentences belongs in docs
