# Contributing to Terraform AWS DR Infrastructure

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers and help them learn
- Focus on constructive feedback
- Maintain professional communication

## Getting Started

### Prerequisites

- Terraform >= 1.6.0
- AWS CLI >= 2.0
- Git
- Basic understanding of AWS services
- Familiarity with Infrastructure as Code concepts

### Development Setup

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/terraform-aws-dr-infrastructure.git
   cd terraform-aws-dr-infrastructure
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Configure AWS credentials**
   ```bash
   aws configure
   ```

## Development Workflow

### Branching Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/*` - New features
- `bugfix/*` - Bug fixes
- `hotfix/*` - Emergency fixes
- `release/*` - Release preparation

### Making Changes

1. **Write clean, documented code**
   - Follow Terraform best practices
   - Add comments for complex logic
   - Use meaningful variable names

2. **Format your code**
   ```bash
   terraform fmt -recursive
   ```

3. **Validate your changes**
   ```bash
   terraform validate
   ```

4. **Run security scans**
   ```bash
   tfsec .
   checkov -d .
   ```

5. **Test your changes**
   - Test in a development environment
   - Verify all modules work correctly
   - Check for breaking changes

### Commit Guidelines

Follow conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Adding tests
- `chore`: Maintenance tasks

**Examples:**
```
feat(compute): add support for t3 instance types

Added support for t3.micro and t3.small instance types
in the compute module for better performance.

Closes #123
```

```
fix(database): correct RDS backup window validation

Fixed validation logic for backup window to accept
proper time format.
```

### Pull Request Process

1. **Update documentation**
   - Update README if needed
   - Add/update module documentation
   - Update CHANGELOG.md

2. **Create pull request**
   - Use descriptive title
   - Fill out PR template
   - Link related issues
   - Add screenshots if applicable

3. **Code review**
   - Address review comments
   - Keep PR focused and small
   - Rebase if needed

4. **Merge requirements**
   - All CI checks pass
   - At least one approval
   - No merge conflicts
   - Documentation updated

## Module Development

### Module Structure

```
modules/
└── module-name/
    ├── main.tf          # Main resources
    ├── variables.tf     # Input variables
    ├── outputs.tf       # Output values
    ├── versions.tf      # Provider versions (optional)
    └── README.md        # Module documentation
```

### Module Guidelines

1. **Single Responsibility**
   - Each module should have one clear purpose
   - Keep modules focused and reusable

2. **Input Variables**
   - Provide sensible defaults
   - Add validation where appropriate
   - Document all variables

3. **Outputs**
   - Export useful values
   - Document output purposes
   - Use descriptive names

4. **Documentation**
   - Explain module purpose
   - Provide usage examples
   - Document requirements

### Example Module

```hcl
# modules/example/main.tf
resource "aws_instance" "example" {
  ami           = var.ami_id
  instance_type = var.instance_type

  tags = merge(
    var.common_tags,
    {
      Name = "${var.project_name}-example"
    }
  )
}

# modules/example/variables.tf
variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
  validation {
    condition     = can(regex("^ami-", var.ami_id))
    error_message = "AMI ID must start with 'ami-'."
  }
}

variable "instance_type" {
  description = "Instance type"
  type        = string
  default     = "t2.micro"
}

variable "common_tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

# modules/example/outputs.tf
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.example.id
}

output "instance_public_ip" {
  description = "Public IP of the instance"
  value       = aws_instance.example.public_ip
}
```

## Testing

### Manual Testing

1. **Plan and review**
   ```bash
   terraform plan
   ```

2. **Apply in test environment**
   ```bash
   terraform apply
   ```

3. **Verify resources**
   ```bash
   ./scripts/validate-deployment.sh
   ```

4. **Clean up**
   ```bash
   terraform destroy
   ```

### Automated Testing

- CI/CD runs automatically on PR
- Includes format check, validation, security scans
- Must pass before merge

## Documentation

### Required Documentation

1. **Code Comments**
   - Explain complex logic
   - Document workarounds
   - Add TODOs for future improvements

2. **README Updates**
   - Update if adding features
   - Keep examples current
   - Update prerequisites

3. **CHANGELOG**
   - Add entry for changes
   - Follow Keep a Changelog format
   - Include version and date

### Documentation Style

- Use clear, concise language
- Provide examples
- Include diagrams where helpful
- Keep formatting consistent

## Security

### Security Best Practices

1. **Never commit secrets**
   - Use AWS Secrets Manager
   - Use environment variables
   - Add sensitive files to .gitignore

2. **Follow least privilege**
   - Minimal IAM permissions
   - Restrict security groups
   - Use private subnets

3. **Enable encryption**
   - Encrypt data at rest
   - Use TLS for data in transit
   - Rotate encryption keys

### Reporting Security Issues

- **DO NOT** open public issues for security vulnerabilities
- Email security concerns to: security@example.com
- Include detailed description and steps to reproduce

## Release Process

1. **Update version**
   - Follow semantic versioning
   - Update CHANGELOG.md
   - Tag release

2. **Create release branch**
   ```bash
   git checkout -b release/v1.0.0
   ```

3. **Final testing**
   - Run full test suite
   - Verify documentation
   - Check for breaking changes

4. **Merge and tag**
   ```bash
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   ```

## Getting Help

- **Documentation**: Check docs/ directory
- **Issues**: Search existing issues
- **Discussions**: Use GitHub Discussions
- **Questions**: Open an issue with "question" label

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing! 🎉
