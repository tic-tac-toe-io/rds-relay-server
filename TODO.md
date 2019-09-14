


## Better Authentication for Web Terminal (`/tty`) page

- Use basic authentication to login before displaying all agents.
- Use user definitions from `auth.userdb.agent` section from YAML configuration file.
- For the generated HTML page after login, onetime session token shall be generated and embedded to HTML codes. Then, javascript of web terminal can use that token to establish socket.io connection.
- When web terminal detects socket.io connection is disconnected, and reconnected to server, please reload entire HTML page to ensure the session token can be renewed
- At server side, the one-time session token shall be expired in 10 minutes.
- At web terminal, when socket.io connection is failed to connect due to session token expiry, the entire web page shall be reloaded again



## Web Terminal supports Agent Sorting

- be able to sort agents in different attributes
  - `profile`
  - `location`
  - `ip address`
- if the number of agents in a specific group is only ONE, then this group shall be merged with other groups



## TTY lifecycle event

In addition to the `agent-connected` and `agent-disconnected` lifecycle events, Web Terminal also needs to know when one tty session for an agent is established or destroyed, then Web Terminal can update UI controls to avoid users to create TTY session on an agent in that there is another TTY session.

- `agent-tty-established`
- `agent-tty-destroyed`
- `agent-tty-transmitted`

