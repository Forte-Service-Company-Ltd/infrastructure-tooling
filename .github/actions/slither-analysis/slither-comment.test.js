const assert = require('node:assert/strict');
const test = require('node:test');
const {
  MARKER,
  extractJsonFindings,
  findExistingComment,
  renderReport,
} = require('./slither-comment');

const repositoryUrl = 'https://github.com/acme/contracts';
const headSha = '0123456789abcdef';
const runUrl = 'https://github.com/acme/contracts/actions/runs/42';

test('uses exact Slither JSON impact and confidence and links every location', () => {
  const findings = extractJsonFindings({
    results: {
      detectors: [{
        check: 'reentrancy-eth',
        impact: 'High',
        confidence: 'Medium',
        description: 'Reentrancy in withdraw()',
        elements: [
          { source_mapping: { filename_relative: 'src/Vault.sol', lines: [12, 13] } },
          { source_mapping: { filename_relative: 'src/Library.sol', lines: [7] } },
        ],
      }],
    },
  });
  const report = renderReport({ findings, repositoryUrl, headSha, runUrl });

  assert.match(report, /^<!-- slither-analysis-report -->\n# 🔍 Slither Analysis Report/);
  assert.match(report, /\*\*High: 1\*\* · \*\*Medium: 0\*\*/);
  assert.match(report, /## High \(1\)/);
  assert.match(report, /`reentrancy-eth` \(1\)/);
  assert.match(report, /\*\*High impact · Medium confidence\*\*/);
  assert.match(report, /blob\/0123456789abcdef\/src\/Vault\.sol#L12-L13/);
  assert.match(report, /blob\/0123456789abcdef\/src\/Library\.sol#L7/);
});

test('orders impacts, groups detectors, and collapses only lower impacts', () => {
  const findings = [
    { detector: 'z-low', impact: 'Low', confidence: 'High', message: 'low', locations: [] },
    { detector: 'b-high', impact: 'High', confidence: 'High', message: 'high b', locations: [] },
    { detector: 'a-high', impact: 'High', confidence: 'Low', message: 'high a', locations: [] },
    { detector: 'medium', impact: 'Medium', confidence: 'Medium', message: 'medium', locations: [] },
    { detector: 'gas', impact: 'Optimization', confidence: 'High', message: 'gas', locations: [] },
  ];
  const report = renderReport({ findings, repositoryUrl, headSha, runUrl });

  assert.ok(report.indexOf('## High') < report.indexOf('## Medium'));
  assert.ok(report.indexOf('`a-high`') < report.indexOf('`b-high`'));
  assert.match(report, /<summary><strong>Low \(1\)<\/strong><\/summary>/);
  assert.match(report, /<summary><strong>Optimization \(1\)<\/strong><\/summary>/);
  assert.doesNotMatch(report, /<summary><strong>High/);
  assert.doesNotMatch(report, /<summary><strong>Medium/);
});

test('truncates oversized reports and preserves the run and artifact link', () => {
  const findings = Array.from({ length: 20 }, (_, index) => ({
    detector: `detector-${index}`,
    impact: index % 2 ? 'High' : 'Medium',
    confidence: 'High',
    message: 'x'.repeat(200),
    locations: [{ file: `src/C${index}.sol`, startLine: index + 1, endLine: index + 1 }],
  }));
  const report = renderReport({ findings, repositoryUrl, headSha, runUrl, maxLength: 900 });

  assert.ok(report.length <= 900);
  assert.match(report, /Report truncated/);
  assert.match(report, /actions\/runs\/42#artifacts/);
  assert.match(report, /detector-1/);
  assert.doesNotMatch(report, /detector-19/);
  assert.ok(report.startsWith(MARKER));
});

test('finds the marker comment and migrates the previous bot report', () => {
  const spoofed = { id: 3, user: { id: 99 }, body: `${MARKER}\nreport` };
  const marked = { id: 4, user: { id: 41898282 }, body: `${MARKER}\nreport` };
  const oldBotReport = { id: 2, user: { id: 41898282 }, body: '🔍 Slither Analysis Report' };
  const comments = [
    { id: 1, user: { id: 41898282 }, body: 'unrelated' },
    oldBotReport,
    spoofed,
    marked,
  ];

  assert.equal(findExistingComment(comments), marked);
  assert.equal(findExistingComment(comments.slice(0, 2)), oldBotReport);
  assert.equal(findExistingComment([spoofed]), undefined);
});
