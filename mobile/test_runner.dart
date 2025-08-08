#!/usr/bin/env dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// Comprehensive test runner for Lens AI mobile app
/// 
/// This script provides a centralized way to run all tests with various configurations
/// and generate comprehensive reports.

void main(List<String> args) async {
  final runner = TestRunner();
  await runner.run(args);
}

class TestRunner {
  static const String projectRoot = '.';
  
  final List<TestSuite> testSuites = [
    TestSuite(
      name: 'Unit Tests',
      path: 'test/services/**/*_test.dart test/core/**/*_test.dart test/providers/**/*_test.dart',
      description: 'Unit tests for individual components',
      critical: true,
    ),
    TestSuite(
      name: 'Widget Tests',
      path: 'test/screens/**/*_test.dart test/widgets/**/*_test.dart',
      description: 'Widget and UI component tests',
      critical: true,
    ),
    TestSuite(
      name: 'Integration Tests',
      path: 'test/integration/**/*_test.dart',
      description: 'Component integration tests',
      critical: true,
    ),
    TestSuite(
      name: 'Error Handling Tests',
      path: 'test/error_handling/**/*_test.dart',
      description: 'Error handling and recovery tests',
      critical: true,
    ),
    TestSuite(
      name: 'Performance Tests',
      path: 'test/benchmarks/**/*_test.dart test/core/state/performance_tests.dart',
      description: 'Performance and benchmark tests',
      critical: false,
    ),
    TestSuite(
      name: 'End-to-End Tests',
      path: 'test/e2e/**/*_test.dart',
      description: 'Full user workflow tests',
      critical: false,
    ),
  ];

  Future<void> run(List<String> args) async {
    debugPrint('🚀 Lens AI Mobile Test Runner');
    debugPrint('==============================\n');

    final config = TestConfig.fromArgs(args);
    
    if (config.help) {
      _printHelp();
      return;
    }

    if (config.listSuites) {
      _listTestSuites();
      return;
    }

    await _runTests(config);
  }

  Future<void> _runTests(TestConfig config) async {
    final results = <TestResult>[];
    var totalTime = 0;
    var totalTests = 0;
    var totalPassed = 0;
    var totalFailed = 0;

    debugPrint('📋 Test Configuration:');
    debugPrint('  Coverage: ${config.coverage ? 'Enabled' : 'Disabled'}');
    debugPrint('  Concurrency: ${config.concurrency}');
    debugPrint('  Output: ${config.reporter}');
    debugPrint('  Critical Only: ${config.criticalOnly}');
    debugPrint('');

    // Run dependency check
    if (!await _checkDependencies()) {
      debugPrint('❌ Dependency check failed');
      exit(1);
    }

    // Clean previous test artifacts
    await _cleanTestArtifacts();

    final stopwatch = Stopwatch()..start();

    for (final suite in testSuites) {
      if (config.criticalOnly && !suite.critical) {
        debugPrint('⏭️  Skipping ${suite.name} (not critical)');
        continue;
      }

      if (config.suiteFilter != null && !suite.name.toLowerCase().contains(config.suiteFilter!.toLowerCase())) {
        debugPrint('⏭️  Skipping ${suite.name} (filtered)');
        continue;
      }

      debugPrint('🧪 Running ${suite.name}...');
      final result = await _runTestSuite(suite, config);
      results.add(result);

      totalTime += result.duration;
      totalTests += result.totalTests;
      totalPassed += result.passedTests;
      totalFailed += result.failedTests;

      if (result.success) {
        debugPrint('✅ ${suite.name} - ${result.passedTests} passed');
      } else {
        debugPrint('❌ ${suite.name} - ${result.failedTests} failed');
        if (config.failFast) {
          debugPrint('🛑 Stopping due to test failure (fail-fast enabled)');
          break;
        }
      }
      debugPrint('');
    }

    stopwatch.stop();

    // Generate reports
    await _generateReports(results, config);

    // Print summary
    _printSummary(results, totalTests, totalPassed, totalFailed, stopwatch.elapsedMilliseconds);

    // Exit with appropriate code
    final hasFailures = results.any((r) => !r.success);
    exit(hasFailures ? 1 : 0);
  }

  Future<TestResult> _runTestSuite(TestSuite suite, TestConfig config) async {
    final stopwatch = Stopwatch()..start();
    
    final args = <String>[
      'test',
      if (config.coverage) '--coverage',
      if (config.concurrency > 1) '--concurrency=${config.concurrency}',
      '--reporter=${config.reporter}',
      if (config.testNameFilter != null) '--name=${config.testNameFilter}',
      suite.path,
    ];

    final result = await Process.run(
      'flutter',
      args,
      workingDirectory: projectRoot,
    );

    stopwatch.stop();

    return TestResult(
      suiteName: suite.name,
      success: result.exitCode == 0,
      output: result.stdout.toString(),
      errors: result.stderr.toString(),
      duration: stopwatch.elapsedMilliseconds,
      totalTests: _parseTestCount(result.stdout.toString()),
      passedTests: _parsePassedCount(result.stdout.toString()),
      failedTests: _parseFailedCount(result.stdout.toString()),
    );
  }

  Future<bool> _checkDependencies() async {
    debugPrint('🔍 Checking dependencies...');
    
    // Check Flutter
    final flutterResult = await Process.run('flutter', ['--version']);
    if (flutterResult.exitCode != 0) {
      debugPrint('❌ Flutter not found');
      return false;
    }

    // Check if packages are up to date
    final pubGetResult = await Process.run('flutter', ['pub', 'get'], workingDirectory: projectRoot);
    if (pubGetResult.exitCode != 0) {
      debugPrint('❌ Failed to get dependencies');
      return false;
    }

    debugPrint('✅ Dependencies OK');
    return true;
  }

  Future<void> _cleanTestArtifacts() async {
    debugPrint('🧹 Cleaning test artifacts...');
    
    final artifacts = [
      'coverage',
      'test-results',
      '.dart_tool/test',
    ];

    for (final artifact in artifacts) {
      final dir = Directory('$projectRoot/$artifact');
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  }

  Future<void> _generateReports(List<TestResult> results, TestConfig config) async {
    debugPrint('📊 Generating reports...');

    final reportsDir = Directory('$projectRoot/test-results');
    await reportsDir.create(recursive: true);

    // Generate JSON report
    await _generateJsonReport(results, reportsDir);

    // Generate HTML report if coverage enabled
    if (config.coverage) {
      await _generateCoverageReport(reportsDir);
    }

    // Generate performance report
    await _generatePerformanceReport(results, reportsDir);
  }

  Future<void> _generateJsonReport(List<TestResult> results, Directory reportsDir) async {
    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'summary': {
        'totalSuites': results.length,
        'passedSuites': results.where((r) => r.success).length,
        'failedSuites': results.where((r) => !r.success).length,
        'totalTests': results.fold(0, (sum, r) => sum + r.totalTests),
        'passedTests': results.fold(0, (sum, r) => sum + r.passedTests),
        'failedTests': results.fold(0, (sum, r) => sum + r.failedTests),
        'totalDuration': results.fold(0, (sum, r) => sum + r.duration),
      },
      'suites': results.map((r) => r.toJson()).toList(),
    };

    final file = File('${reportsDir.path}/test-results.json');
    await file.writeAsString(_prettyJson(report));
  }

  Future<void> _generateCoverageReport(Directory reportsDir) async {
    final lcovFile = File('$projectRoot/coverage/lcov.info');
    if (await lcovFile.exists()) {
      // Generate HTML coverage report
      final result = await Process.run(
        'genhtml',
        [
          'coverage/lcov.info',
          '-o', '${reportsDir.path}/coverage',
          '--title', 'Lens AI Test Coverage',
        ],
        workingDirectory: projectRoot,
      );

      if (result.exitCode == 0) {
        debugPrint('📊 Coverage report: ${reportsDir.path}/coverage/index.html');
      }
    }
  }

  Future<void> _generatePerformanceReport(List<TestResult> results, Directory reportsDir) async {
    final performanceResults = results.where((r) => 
      r.suiteName.toLowerCase().contains('performance') || 
      r.suiteName.toLowerCase().contains('benchmark')
    ).toList();

    if (performanceResults.isEmpty) return;

    final report = {
      'timestamp': DateTime.now().toIso8601String(),
      'performance': {
        'averageSuiteDuration': performanceResults.fold(0, (sum, r) => sum + r.duration) / performanceResults.length,
        'slowestSuite': performanceResults.reduce((a, b) => a.duration > b.duration ? a : b).suiteName,
        'fastestSuite': performanceResults.reduce((a, b) => a.duration < b.duration ? a : b).suiteName,
      },
      'details': performanceResults.map((r) => {
        'suite': r.suiteName,
        'duration': r.duration,
        'testsPerSecond': r.totalTests / (r.duration / 1000),
      }).toList(),
    };

    final file = File('${reportsDir.path}/performance-report.json');
    await file.writeAsString(_prettyJson(report));
  }

  void _printSummary(List<TestResult> results, int totalTests, int totalPassed, int totalFailed, int totalTime) {
    debugPrint('📈 Test Summary');
    debugPrint('===============');
    debugPrint('Total Test Suites: ${results.length}');
    debugPrint('Passed Suites: ${results.where((r) => r.success).length}');
    debugPrint('Failed Suites: ${results.where((r) => !r.success).length}');
    debugPrint('');
    debugPrint('Total Tests: $totalTests');
    debugPrint('Passed Tests: $totalPassed');
    debugPrint('Failed Tests: $totalFailed');
    debugPrint('Success Rate: ${totalTests > 0 ? ((totalPassed / totalTests) * 100).toStringAsFixed(1) : 0}%');
    debugPrint('');
    debugPrint('Total Duration: ${(totalTime / 1000).toStringAsFixed(2)}s');
    debugPrint('');

    if (totalFailed == 0) {
      debugPrint('🎉 All tests passed!');
    } else {
      debugPrint('💥 $totalFailed test(s) failed');
      debugPrint('');
      debugPrint('Failed Suites:');
      for (final result in results.where((r) => !r.success)) {
        debugPrint('  - ${result.suiteName}');
      }
    }
  }

  void _listTestSuites() {
    debugPrint('Available Test Suites:');
    debugPrint('======================');
    for (final suite in testSuites) {
      debugPrint('${suite.name}${suite.critical ? ' (critical)' : ''}');
      debugPrint('  ${suite.description}');
      debugPrint('  Path: ${suite.path}');
      debugPrint('');
    }
  }

  void _printHelp() {
    debugPrint('Usage: dart test_runner.dart [options]');
    debugPrint('');
    debugPrint('Options:');
    debugPrint('  --coverage              Enable test coverage');
    debugPrint('  --concurrency=N         Set test concurrency (default: 4)');
    debugPrint('  --reporter=TYPE         Set test reporter (compact, expanded, json)');
    debugPrint('  --critical-only         Run only critical test suites');
    debugPrint('  --fail-fast             Stop on first test failure');
    debugPrint('  --suite=NAME            Filter test suites by name');
    debugPrint('  --name=PATTERN          Filter tests by name pattern');
    debugPrint('  --list-suites           List available test suites');
    debugPrint('  --help                  Show this help message');
    debugPrint('');
    debugPrint('Examples:');
    debugPrint('  dart test_runner.dart --coverage --critical-only');
    debugPrint('  dart test_runner.dart --suite="Unit Tests" --concurrency=8');
    debugPrint('  dart test_runner.dart --name="AI.*test" --fail-fast');
  }

  // Helper methods for parsing test output
  int _parseTestCount(String output) {
    final match = RegExp(r'All tests passed! \((\d+) tests?\)').firstMatch(output);
    if (match != null) return int.parse(match.group(1)!);
    
    final runMatch = RegExp(r'(\d+) tests? passed').firstMatch(output);
    if (runMatch != null) return int.parse(runMatch.group(1)!);
    
    return 0;
  }

  int _parsePassedCount(String output) {
    final match = RegExp(r'(\d+) tests? passed').firstMatch(output);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  int _parseFailedCount(String output) {
    final match = RegExp(r'(\d+) tests? failed').firstMatch(output);
    return match != null ? int.parse(match.group(1)!) : 0;
  }

  String _prettyJson(Object obj) {
    return const JsonEncoder.withIndent('  ').convert(obj);
  }
}

class TestConfig {
  final bool coverage;
  final int concurrency;
  final String reporter;
  final bool criticalOnly;
  final bool failFast;
  final String? suiteFilter;
  final String? testNameFilter;
  final bool listSuites;
  final bool help;

  TestConfig({
    this.coverage = false,
    this.concurrency = 4,
    this.reporter = 'compact',
    this.criticalOnly = false,
    this.failFast = false,
    this.suiteFilter,
    this.testNameFilter,
    this.listSuites = false,
    this.help = false,
  });

  factory TestConfig.fromArgs(List<String> args) {
    var coverage = false;
    var concurrency = 4;
    var reporter = 'compact';
    var criticalOnly = false;
    var failFast = false;
    String? suiteFilter;
    String? testNameFilter;
    var listSuites = false;
    var help = false;

    for (final arg in args) {
      if (arg == '--coverage') {
        coverage = true;
      } else if (arg.startsWith('--concurrency=')) {
        concurrency = int.tryParse(arg.split('=')[1]) ?? 4;
      } else if (arg.startsWith('--reporter=')) {
        reporter = arg.split('=')[1];
      } else if (arg == '--critical-only') {
        criticalOnly = true;
      } else if (arg == '--fail-fast') {
        failFast = true;
      } else if (arg.startsWith('--suite=')) {
        suiteFilter = arg.split('=')[1];
      } else if (arg.startsWith('--name=')) {
        testNameFilter = arg.split('=')[1];
      } else if (arg == '--list-suites') {
        listSuites = true;
      } else if (arg == '--help' || arg == '-h') {
        help = true;
      }
    }

    return TestConfig(
      coverage: coverage,
      concurrency: concurrency,
      reporter: reporter,
      criticalOnly: criticalOnly,
      failFast: failFast,
      suiteFilter: suiteFilter,
      testNameFilter: testNameFilter,
      listSuites: listSuites,
      help: help,
    );
  }
}

class TestSuite {
  final String name;
  final String path;
  final String description;
  final bool critical;

  TestSuite({
    required this.name,
    required this.path,
    required this.description,
    required this.critical,
  });
}

class TestResult {
  final String suiteName;
  final bool success;
  final String output;
  final String errors;
  final int duration;
  final int totalTests;
  final int passedTests;
  final int failedTests;

  TestResult({
    required this.suiteName,
    required this.success,
    required this.output,
    required this.errors,
    required this.duration,
    required this.totalTests,
    required this.passedTests,
    required this.failedTests,
  });

  Map<String, dynamic> toJson() => {
    'suiteName': suiteName,
    'success': success,
    'duration': duration,
    'totalTests': totalTests,
    'passedTests': passedTests,
    'failedTests': failedTests,
    'output': output.length > 1000 ? '${output.substring(0, 1000)}...' : output,
    'errors': errors.length > 1000 ? '${errors.substring(0, 1000)}...' : errors,
  };
}

