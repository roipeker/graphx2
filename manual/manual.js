const content = document.querySelector('#content');
const menuButton = document.querySelector('#menuButton');

function escapeHtml(value) {
  return value.replace(/[&<>]/g, (char) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' })[char]);
}

function inline(text) {
  return escapeHtml(text)
    .replace(/`([^`]+)`/g, '<code>$1</code>')
    .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2">$1</a>');
}

function markdown(source) {
  const lines = source.replace(/\r/g, '').split('\n');
  const out = [];
  let paragraph = [];
  let list = [];
  let code = [];
  let inCode = false;

  const flushParagraph = () => {
    if (!paragraph.length) return;
    out.push(`<p>${inline(paragraph.join(' '))}</p>`);
    paragraph = [];
  };
  const flushList = () => {
    if (!list.length) return;
    out.push(`<ul>${list.map((item) => `<li>${inline(item)}</li>`).join('')}</ul>`);
    list = [];
  };

  for (const line of lines) {
    if (line.startsWith('```')) {
      flushParagraph();
      flushList();
      if (!inCode) {
        inCode = true;
        code = [];
      } else {
        out.push(`<pre><code>${escapeHtml(code.join('\n'))}</code></pre>`);
        inCode = false;
      }
      continue;
    }
    if (inCode) {
      code.push(line);
      continue;
    }
    if (!line.trim()) {
      flushParagraph();
      flushList();
      continue;
    }
    if (line.startsWith('# ')) {
      flushParagraph();
      flushList();
      out.push(`<h1>${inline(line.slice(2))}</h1>`);
      continue;
    }
    if (line.startsWith('## ')) {
      flushParagraph();
      flushList();
      const label = line.slice(3);
      const id = label.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
      out.push(`<h2 id="${id}">${inline(label)}</h2>`);
      continue;
    }
    if (line.startsWith('- ')) {
      flushParagraph();
      list.push(line.slice(2));
      continue;
    }
    paragraph.push(line.trim());
  }

  flushParagraph();
  flushList();
  return out.join('\n');
}

async function loadPage(path) {
  content.innerHTML = '<p class="loading">Loading the manual…</p>';
  try {
    const response = await fetch(path);
    if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
    content.innerHTML = markdown(await response.text());
    document.body.classList.remove('menu-open');
    window.scrollTo({ top: 0, behavior: 'instant' });
  } catch (error) {
    content.innerHTML = `<h1>Manual</h1><p>Could not load this page.</p><pre><code>${escapeHtml(String(error))}</code></pre>`;
  }
}

menuButton.addEventListener('click', () => document.body.classList.toggle('menu-open'));
document.querySelectorAll('[data-page]').forEach((link) => {
  link.addEventListener('click', (event) => {
    event.preventDefault();
    document.querySelectorAll('.nav-link.active').forEach((item) => item.classList.remove('active'));
    link.classList.add('active');
    history.replaceState(null, '', link.getAttribute('href'));
    loadPage(link.dataset.page);
  });
});

loadPage('welcome.md');
