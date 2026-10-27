const IMPACTS = ['High', 'Medium', 'Low', 'Informational', 'Optimization'];
const DEFAULT_MAX_LENGTH = 60000;
const MAX_MESSAGE_LENGTH = 4000;
const MARKER = '<!-- slither-analysis-report -->';
const GITHUB_ACTIONS_BOT_ID = 41898282;

function normalizeClassification(value, allowed, fallback) {
  if (typeof value !== 'string') return fallback;
  return allowed.find((item) => item.toLowerCase() === value.toLowerCase()) || fallback;
}

function extractJsonFindings(slitherJson) {
  const detectors = slitherJson?.results?.detectors;
  if (!Array.isArray(detectors)) return [];

  return detectors.map((finding) => ({
    detector: finding.check || 'unknown',
    impact: normalizeClassification(finding.impact, IMPACTS, 'Informational'),
    confidence: normalizeClassification(
      finding.confidence,
      ['High', 'Medium', 'Low', 'Informational'],
      'Informational',
    ),
    message: finding.description || 'No description provided.',
    locations: extractJsonLocations(finding.elements),
  }));
}

function extractJsonLocations(elements) {
  if (!Array.isArray(elements)) return [];
  return elements.flatMap((element) => {
    const mapping = element?.source_mapping;
    const file = mapping?.filename_relative || mapping?.filename_short;
    const lines = Array.isArray(mapping?.lines) ? mapping.lines.filter(Number.isInteger) : [];
    if (!file || lines.length === 0) return [];
    return [{ file, startLine: Math.min(...lines), endLine: Math.max(...lines) }];
  });
}

function uniqueLocations(locations) {
  const seen = new Set();
  return locations.filter((location) => {
    const key = `${location.file}:${location.startLine}:${location.endLine}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

function encodePath(file) {
  return String(file)
    .replace(/^file:\/\//, '')
    .replace(/^\.\//, '')
    .replace(/^\//, '')
    .split('/')
    .map(encodeURIComponent)
    .join('/');
}

function renderLocation(location, repositoryUrl, headSha) {
  const file = String(location.file).replace(/^\.\//, '');
  const lineLabel = location.endLine > location.startLine
    ? `L${location.startLine}-L${location.endLine}`
    : `L${location.startLine}`;
  const url = `${repositoryUrl}/blob/${encodeURIComponent(headSha)}/${encodePath(file)}#${lineLabel}`;
  return `[\`${file}:${lineLabel.replace('L', '').replace('-L', '-')}\`](${url})`;
}

function truncateMessage(message) {
  const normalized = String(message).trim();
  if (normalized.length <= MAX_MESSAGE_LENGTH) return normalized;
  return `${normalized.slice(0, MAX_MESSAGE_LENGTH - 30)}\n\n_Description truncated._`;
}

function renderFinding(finding, index, repositoryUrl, headSha) {
  const locations = uniqueLocations(finding.locations || []);
  const locationText = locations.length > 0
    ? locations.map((location) => renderLocation(location, repositoryUrl, headSha)).join(', ')
    : '_No source location reported._';
  const message = truncateMessage(finding.message).replace(/\n/g, '\n   ');
  return `${index}. **${finding.impact} impact · ${finding.confidence} confidence** — ${locationText}\n\n   ${message}\n\n`;
}

function groupFindings(findings) {
  const grouped = new Map(IMPACTS.map((impact) => [impact, new Map()]));
  for (const finding of findings) {
    const impact = IMPACTS.includes(finding.impact) ? finding.impact : 'Informational';
    const detector = finding.detector || 'unknown';
    if (!grouped.get(impact).has(detector)) grouped.get(impact).set(detector, []);
    grouped.get(impact).get(detector).push(finding);
  }
  return grouped;
}

function renderCounts(findings) {
  const counts = Object.fromEntries(IMPACTS.map((impact) => [impact, 0]));
  findings.forEach((finding) => { counts[finding.impact] = (counts[finding.impact] || 0) + 1; });
  return IMPACTS.map((impact) => `**${impact}: ${counts[impact]}**`).join(' · ');
}

function renderImpactSection(impact, detectors, repositoryUrl, headSha) {
  const expanded = impact === 'High' || impact === 'Medium';
  const count = [...detectors.values()].reduce((total, findings) => total + findings.length, 0);
  let body = expanded
    ? `## ${impact} (${count})\n\n`
    : `<details>\n<summary><strong>${impact} (${count})</strong></summary>\n\n`;
  for (const [detector, findings] of [...detectors].sort(([a], [b]) => a.localeCompare(b))) {
    body += `### \`${detector}\` (${findings.length})\n\n`;
    findings.forEach((finding, index) => {
      body += renderFinding(finding, index + 1, repositoryUrl, headSha);
    });
  }
  if (!expanded) body += '</details>\n\n';
  return body;
}

function orderedFindings(findings) {
  const grouped = groupFindings(findings);
  return IMPACTS.flatMap((impact) =>
    [...grouped.get(impact)]
      .sort(([a], [b]) => a.localeCompare(b))
      .flatMap(([, detectorFindings]) => detectorFindings));
}

function renderSections(findings, repositoryUrl, headSha) {
  const grouped = groupFindings(findings);
  return IMPACTS
    .filter((impact) => grouped.get(impact).size > 0)
    .map((impact) => renderImpactSection(impact, grouped.get(impact), repositoryUrl, headSha))
    .join('');
}

function renderReport({ findings, repositoryUrl, headSha, runUrl, maxLength = DEFAULT_MAX_LENGTH }) {
  const intro = `${MARKER}\n# 🔍 Slither Analysis Report\n\n${renderCounts(findings)}\n\n`;
  const noFindings = '✅ No issues found.\n';
  const sections = renderSections(findings, repositoryUrl, headSha);
  const artifactLink = `[workflow run and SARIF artifact](${runUrl}#artifacts)`;
  const footer = `\n---\nView the ${artifactLink}.\n`;
  const complete = intro + (sections || noFindings) + footer;
  if (complete.length <= maxLength) return complete;

  const notice = `\n> Report truncated to stay within GitHub's comment limit. View the complete ${artifactLink}.\n`;
  const ordered = orderedFindings(findings);
  let lowerBound = 0;
  let upperBound = ordered.length;
  while (lowerBound < upperBound) {
    const candidateCount = Math.ceil((lowerBound + upperBound) / 2);
    const candidate = renderSections(ordered.slice(0, candidateCount), repositoryUrl, headSha);
    if ((intro + candidate + notice + footer).length <= maxLength) {
      lowerBound = candidateCount;
    } else {
      upperBound = candidateCount - 1;
    }
  }
  const truncatedSections = renderSections(ordered.slice(0, lowerBound), repositoryUrl, headSha);
  const body = truncatedSections || '_Finding details omitted because the report is too long._\n';
  return intro + body + notice + footer;
}

function findExistingComment(comments) {
  const botComments = comments.filter((comment) => comment.user?.id === GITHUB_ACTIONS_BOT_ID);
  return botComments.find((comment) => comment.body?.includes(MARKER)) ||
    botComments.find((comment) =>
      comment.body?.includes('🔍 Slither Analysis Report'));
}

module.exports = {
  DEFAULT_MAX_LENGTH,
  IMPACTS,
  MARKER,
  extractJsonFindings,
  findExistingComment,
  renderReport,
};
