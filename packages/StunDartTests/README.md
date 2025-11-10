# StunDartTests

Test suite for the StunDart package.

## Running Tests

```bash
dart test
```

## Test Coverage

Run tests with coverage:

```bash
dart test --coverage=coverage
dart pub global activate coverage
dart pub global run coverage:format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib
```
