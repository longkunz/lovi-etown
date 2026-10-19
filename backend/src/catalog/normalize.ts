export function normalizeText(value: string | null | undefined): string {
  if (value === null || value === undefined) {
    return '';
  }

  const str = String(value).trim().toLowerCase();
  if (!str) {
    return '';
  }

  // Decompose accents, remove combining diacritical marks
  let normalized = str.normalize('NFD').replace(/[\u0300-\u036f]/g, '');

  // Convert Vietnamese đ and Đ to d
  normalized = normalized.replace(/[\u0111\u0110]/g, 'd');

  // Collapse multiple whitespaces
  return normalized.replace(/\s+/g, ' ').trim();
}
