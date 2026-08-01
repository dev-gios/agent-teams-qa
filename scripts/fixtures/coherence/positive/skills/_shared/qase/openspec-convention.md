# OpenSpec Convention (positive fixture)

## Review ID Format

The review ID is derived from the PR number or commit hash: `review-{pr-number}` or
`review-{short-sha}`. It is unique per review session and used as a directory prefix under
`qaspec/reviews/`.

### `{flow-slug}` — from a flow name

The flow slug is derived from the user flow name by lowercasing and replacing spaces with hyphens.
Example: "User Login" becomes `user-login`.

### `{page-slug}` — from a URL

The page slug is derived from the URL path by taking the last non-empty path segment and
lowercasing it. Example: `/checkout/payment` yields `payment`.
