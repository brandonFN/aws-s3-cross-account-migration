# Contributing to AWS S3 Cross-Account Migration

First off, thank you for considering contributing to this project! Every contribution helps make this tool better for everyone.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (bucket names can be anonymized)
- **Describe the behavior you observed and what you expected**
- **Include logs** from the generated log file (remove sensitive info)
- **Include your environment details:**
  - OS (macOS, Linux, Windows WSL)
  - AWS CLI version (`aws --version`)
  - Bash version (`bash --version`)

### Suggesting Enhancements

Enhancement suggestions are welcome! Please include:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this would be useful to most users**
- **List any alternatives you've considered**

### Pull Requests

1. Fork the repo and create your branch from `main`
2. Make your changes
3. Test your changes with real S3 buckets (or mock data)
4. Update the README if needed
5. Submit a pull request

## Style Guidelines

### Bash Script Style

- Use meaningful variable names in UPPER_CASE
- Add comments for complex logic
- Use `shellcheck` to validate your code
- Keep functions focused and single-purpose
- Handle errors gracefully

### Commit Messages

- Use the present tense ("Add feature" not "Added feature")
- Use the imperative mood ("Move cursor to..." not "Moves cursor to...")
- Limit the first line to 72 characters
- Reference issues and pull requests when relevant

## Testing

Before submitting a PR, please test:

1. Migration with empty buckets
2. Migration with buckets containing various file types
3. Resuming an interrupted migration
4. Error handling (invalid credentials, permissions issues)

## Questions?

Feel free to open an issue with your question or reach out to the maintainers.

Thank you for contributing!
