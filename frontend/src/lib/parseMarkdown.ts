import { marked } from 'marked';
import DOMPurify from 'dompurify';

export async function parseMarkdown(input: string): Promise<string> {
  const rawHtml = await marked(input, {
    breaks: true,
  });

  return DOMPurify.sanitize(rawHtml, {
    ALLOWED_TAGS: ['strong', 'em', 'br', 'p'],
    ALLOWED_ATTR: []
  });
}