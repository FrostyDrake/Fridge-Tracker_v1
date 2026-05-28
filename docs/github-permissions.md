# GitHub Permissions Guide

Repository: `https://github.com/FrostyDrake/Fridge-Tracker_v1`

## Recommended Access

| Person | Role in project | GitHub access |
| ------ | --------------- | ------------- |
| Andrei | Scrum Master / Backend | Admin or Maintain |
| Azad | Product Owner / Frontend | Write |
| Dylan | Developer / Database | Write |

Use `Write` for Azad and Dylan so they can push branches, create pull requests,
review code, and contribute normally. Keep `Admin` limited to the repository
owner, or use `Maintain` for Andrei if he needs to manage issues, branches, and
project settings without full ownership-level power.

## Invite Collaborators

1. Open GitHub and go to `FrostyDrake/Fridge-Tracker_v1`.
2. Click `Settings`.
3. Click `Collaborators and teams`.
4. Click `Add people`.
5. Search for Azad's GitHub username.
6. Select role `Write`.
7. Send the invitation.
8. Repeat for Dylan with role `Write`.

They must accept the invitation from GitHub before they can push.

## Recommended Branch Rules

After inviting the team, protect the `main` branch:

1. Go to `Settings`.
2. Open `Branches`.
3. Add a branch protection rule for `main`.
4. Enable `Require a pull request before merging`.
5. Enable `Require approvals` and set it to `1`.
6. Enable `Require conversation resolution before merging`.
7. Enable `Do not allow bypassing the above settings` if the team agrees.

Recommended workflow:

```text
main
├── feature/auth-flow
├── feature/fridge-overview
├── feature/manual-add-item
└── feature/delete-item
```

Each feature branch should be merged into `main` through a pull request.
