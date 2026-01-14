# Dev Container for Resque Scheduler

This dev container is configured to match the GitHub Actions test matrix with the following configuration:

- **Ruby version**: 3.3
- **Resque version**: master (from git)
- **Rufus-scheduler**: 3.6
- **Redis version**: latest
- **Rack version**: 3

## Getting Started

1. Open this repository in VS Code
2. When prompted, click "Reopen in Container" (or run the command "Dev Containers: Reopen in Container")
3. Wait for the container to build and start
4. Once inside the container, dependencies will be automatically installed via `bundle install`

## Running Tests

To run the full test suite:

```bash
bundle exec rake
```

To run a specific test file:

```bash
bundle exec ruby test/scheduler_test.rb
```

To run tests with verbose output:

```bash
VERBOSE=1 bundle exec rake
```

To run tests matching a specific pattern:

```bash
PATTERN='test/scheduler_*_test.rb' bundle exec rake
```

## Testing with Different Configurations

If you want to test with different versions, you can modify the environment variables and reinstall dependencies:

```bash
# Example: Test with rufus-scheduler 3.4
export RUFUS_SCHEDULER=3.4
bundle install

# Run tests
bundle exec rake

# Reset to original configuration
export RUFUS_SCHEDULER=3.6
bundle install
```

## Available Environment Variables

The following environment variables are set to match the test matrix:

- `REDIS_VERSION`: latest
- `RESQUE`: master
- `RUFUS_SCHEDULER`: 3.6
- `RACK_VERSION`: 3
- `COVERAGE`: 1

## Services

### Redis
Redis is available at `redis://redis:6379` or via `localhost:6379` from within the container.

To connect to Redis CLI:

```bash
redis-cli -h redis
```

## Troubleshooting

### Bundle Install Issues

If you encounter issues with bundle install, try:

```bash
bundle config set --local build.redis --with-cflags="-Wno-error=implicit-function-declaration"
bundle install
```

### Redis Connection Issues

Make sure Redis is running:

```bash
redis-cli -h redis ping
```

Should return `PONG`.

### Rebuilding the Container

If you need to rebuild the container from scratch:

1. Run "Dev Containers: Rebuild Container" from the command palette
2. Or delete the container and volume manually:
   ```bash
   docker-compose -f .devcontainer/docker-compose.yml down -v
   ```
