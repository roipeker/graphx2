const content = document.querySelector('#content');
const menuButton = document.querySelector('#menuButton');
const links = [...document.querySelectorAll('[data-page]')];

function escapeHtml(value) {
  return value.replace(/[&<>]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[char]);
}

function escapeAttribute(value) {
  return value.replace(/[&"<>]/g, (char) => ({ '&': '&amp;', '"': '&quot;', '<': '&lt;', '>': '&gt;' })[char]);
}

function inline(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>')
    .replace(/\*([^*]+)\*/g, '<em>$1</em>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
}

const dartToken = /\/\/[^\n]*|\/\*[\s\S]*?\*\/|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\b(?:abstract|as|assert|async|await|break|case|catch|class|const|continue|covariant|default|deferred|do|dynamic|else|enum|export|extends|extension|external|factory|false|final|finally|for|Function|get|hide|if|implements|import|in|interface|is|late|library|mixin|new|null|of|on|operator|part|required|rethrow|return|sealed|set|show|static|super|switch|sync|this|throw|true|try|typedef|var|void|when|while|with|yield)\b|\b[A-Z][A-Za-z0-9_]*\b|\b\d+(?:\.\d+)?\b/g;

function highlightDart(code) {
  let html = '';
  let cursor = 0;
  for (const match of code.matchAll(dartToken)) {
    html += escapeHtml(code.slice(cursor, match.index));
    const token = match[0];
    let kind = 'type';
    if (token.startsWith('//') || token.startsWith('/*')) kind = 'comment';
    else if (token.startsWith("'") || token.startsWith('"')) kind = 'string';
    else if (/^\d/.test(token)) kind = 'number';
    else if (/^(true|false|null)$/.test(token)) kind = 'literal';
    else if (/^[a-z]/.test(token)) kind = 'keyword';
    html += `<span class="tok-${kind}">${escapeHtml(token)}</span>`;
    cursor = match.index + token.length;
  }
  return html + escapeHtml(code.slice(cursor));
}

function codeBlock(code, language) {
  const lang = language.toLowerCase();
  const rendered = lang === 'dart' ? highlightDart(code) : escapeHtml(code);
  const label = lang === 'dart' ? 'Dart' : (lang || 'Code');
  return `<div class="code-block"><div class="code-head"><span>${escapeHtml(label)}</span><button class="copy-code" type="button">Copy</button></div><pre><code class="language-${escapeAttribute(lang)}">${rendered}</code></pre></div>`;
}

function markdown(source) {
  const lines = source.replace(/\r/g, '').split('\n');
  const out = [];
  let paragraph = [];
  let list = [];
  let listTag = 'ul';
  let code = [];
  let language = '';
  let inCode = false;

  const flushParagraph = () => {
    if (!paragraph.length) return;
    out.push(`<p>${inline(paragraph.join(' '))}</p>`);
    paragraph = [];
  };
  const flushList = () => {
    if (!list.length) return;
    out.push(`<${listTag}>${list.map((item) => `<li>${inline(item)}</li>`).join('')}</${listTag}>`);
    list = [];
  };

  for (const line of lines) {
    if (line.startsWith('```')) {
      flushParagraph();
      flushList();
      if (!inCode) {
        inCode = true;
        language = line.slice(3).trim();
        code = [];
      } else {
        out.push(codeBlock(code.join('\n'), language));
        inCode = false;
      }
      continue;
    }
    if (inCode) { code.push(line); continue; }
    if (!line.trim()) { flushParagraph(); flushList(); continue; }
    if (line.startsWith('# ')) { flushParagraph(); flushList(); out.push(`<h1>${inline(line.slice(2))}</h1>`); continue; }
    if (line.startsWith('## ')) {
      flushParagraph(); flushList();
      const label = line.slice(3);
      const id = label.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
      out.push(`<h2 id="${id}">${inline(label)}</h2>`);
      continue;
    }
    const image = line.match(/^!\[([^\]]*)\]\(([^)]+)\)$/);
    if (image) {
      flushParagraph(); flushList();
      const alt = image[1];
      const src = image[2];
      out.push(`<figure><img src="${escapeAttribute(src)}" alt="${escapeAttribute(alt)}" loading="lazy">${alt ? `<figcaption>${inline(alt)}</figcaption>` : ''}</figure>`);
      continue;
    }
    if (line.startsWith('> ')) { flushParagraph(); flushList(); out.push(`<blockquote>${inline(line.slice(2))}</blockquote>`); continue; }
    if (line.startsWith('- ')) {
      flushParagraph();
      if (list.length && listTag !== 'ul') flushList();
      listTag = 'ul';
      list.push(line.slice(2));
      continue;
    }
    const ordered = line.match(/^\d+\. (.+)$/);
    if (ordered) {
      flushParagraph();
      if (list.length && listTag !== 'ol') flushList();
      listTag = 'ol';
      list.push(ordered[1]);
      continue;
    }
    paragraph.push(line.trim());
  }

  flushParagraph();
  flushList();
  return out.join('\n');
}

function chapterKicker(link) {
  const number = String(link?.dataset.chapter ?? '1').padStart(2, '0');
  const group = link?.dataset.group ?? 'Start here';
  return `<div class="chapter-kicker">Chapter ${number} · ${escapeHtml(group)}</div>`;
}

function chapterNavigation(link) {
  if (!link) return '';
  const index = links.indexOf(link);
  const previous = index > 0 ? links[index - 1] : null;
  const next = index >= 0 && index < links.length - 1 ? links[index + 1] : null;

  const item = (target, direction) => {
    if (!target) return '<span class="chapter-nav-spacer"></span>';
    const isPrevious = direction === 'previous';
    const label = isPrevious ? 'Previous' : 'Next';
    const arrow = isPrevious ? '←' : '→';
    const title = target.textContent.trim();
    const href = target.getAttribute('href');
    const copy = `<span class="chapter-nav-copy">`
      + `<span class="chapter-nav-label">${label}</span>`
      + `<strong>${escapeHtml(title)}</strong>`
      + '</span>';
    const arrowMark = `<span class="chapter-nav-arrow" aria-hidden="true">${arrow}</span>`;
    return `<a class="chapter-nav-link ${direction}" href="${escapeAttribute(href)}">`
      + (isPrevious ? arrowMark + copy : copy + arrowMark)
      + '</a>';
  };

  return `<nav class="chapter-nav" aria-label="Chapter navigation">`
    + item(previous, 'previous')
    + item(next, 'next')
    + '</nav>';
}

function bindCopyButtons() {
  document.querySelectorAll('.copy-code').forEach((button) => {
    button.addEventListener('click', async () => {
      const code = button.closest('.code-block').querySelector('code').textContent;
      await navigator.clipboard.writeText(code);
      button.textContent = 'Copied';
      setTimeout(() => { button.textContent = 'Copy'; }, 1200);
    });
  });
}

async function loadPage(path, link) {
  content.innerHTML = '<p class="loading">Opening the manual…</p>';
  try {
    const response = await fetch(path);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    content.innerHTML = chapterKicker(link) + markdown(await response.text()) + chapterNavigation(link);
    bindCopyButtons();
    document.body.classList.remove('menu-open');
    window.scrollTo({ top: 0, behavior: 'instant' });
  } catch (error) {
    content.innerHTML = `<h1>Manual</h1><p>Could not load this page.</p><div class="code-block"><pre><code>${escapeHtml(String(error))}</code></pre></div>`;
  }
}

function select(link) {
  links.forEach((item) => item.classList.toggle('active', item === link));
  history.replaceState(null, '', link.getAttribute('href'));
  loadPage(link.dataset.page, link);
}


content.addEventListener('click', (event) => {
  const anchor = event.target.closest('a[href^="#"]');
  if (!anchor) return;
  const link = links.find((item) => item.getAttribute('href') === anchor.getAttribute('href'));
  if (!link) return;
  event.preventDefault();
  select(link);
});

menuButton.addEventListener('click', () => document.body.classList.toggle('menu-open'));
links.forEach((link) => link.addEventListener('click', (event) => { event.preventDefault(); select(link); }));

const initialHash = location.hash.slice(1);
const initial = links.find((link) => link.getAttribute('href') === `#${initialHash}`) ?? links[0];
if (initial) select(initial);
else loadPage(document.body.dataset.firstPage, null);
