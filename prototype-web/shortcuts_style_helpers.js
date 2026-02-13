// Helper UI primitives to mimic Shortcuts list/row aesthetics (no new functionality).
// Intentionally dumb: static DOM builders.

export function scSection(title, children = []) {
  return {
    kind: 'section',
    title,
    children
  };
}
