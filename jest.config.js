/** @type {import('jest').Config} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/.ai/extracted', '<rootDir>/.ai/dashboard'],
  testMatch: ['**/*.test.ts'],
  moduleFileExtensions: ['ts', 'js', 'json'],
  transform: {
    '^.+\\.ts$': 'ts-jest',
  },
  collectCoverageFrom: [
    '.ai/extracted/**/*.ts',
    '!.ai/extracted/**/*.test.ts',
    '.ai/dashboard/**/*.ts',
    '!.ai/dashboard/**/*.test.ts',
  ],
  coverageDirectory: 'coverage',
  coverageReporters: ['text', 'lcov', 'html'],
  setupFilesAfterEnv: ['<rootDir>/.ai/extracted/tests/setup.ts'],
};
