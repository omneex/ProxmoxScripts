/*************************************************************************
 * Configuration and Setup
 *************************************************************************/
const repoOwner = 'coelacant1';
const repoName = 'ProxmoxScripts';
const baseApiURL = `https://api.github.com/repos/${repoOwner}/${repoName}/contents`;
const baseRawURL = `https://github.com/${repoOwner}/${repoName}/raw/main`;

const content = document.getElementById('content');

/*************************************************************************
 * Utilities
 *************************************************************************/

// Format .sh name => "Bulk Add IP Note to V Ms", etc.
function formatFileName(fileName) {
  return fileName.replace('.sh', '').replace(/([A-Z])/g, ' $1').trim();
}

// Parse the top comment block from script content
function parseTopComment(content) {
  console.log('[DEBUG] Parsing script content for top comment...');
  const lines = content.split('\n');
  const commentBlock = [];
  let inCommentBlock = false;

  for (const line of lines) {
    if (line.startsWith('#!')) {
      // Skip shebang
      continue;
    } else if (line.startsWith('#')) {
      inCommentBlock = true;
      commentBlock.push(line.replace(/^#\s*/, '').trim());
    } else if (inCommentBlock) {
      break; // stop at first non-comment line after comments
    }
  }

  const parsedComment = commentBlock.join('\n') || 'No description available.';
  console.log('[DEBUG] Parsed comment block:', parsedComment);
  return parsedComment;
}

/*************************************************************************
 * Fetching Script Content from GitHub
 *************************************************************************/
async function fetchTopComment(filePath) {
  const apiURL = `${baseApiURL}/${filePath}`;
  console.log(`[DEBUG] fetchTopComment(): ${apiURL}`);

  try {
    const response = await fetch(apiURL);
    if (!response.ok) {
      throw new Error(`[ERROR] Failed to fetch script content. Status: ${response.status}`);
    }
    const data = await response.json();
    const decoded = atob(data.content);
    return parseTopComment(decoded);
  } catch (err) {
    console.error(err);
    return 'Unable to load script information.';
  }
}

async function fetchFullScript(filePath) {
  const apiURL = `${baseApiURL}/${filePath}`;
  console.log(`[DEBUG] fetchFullScript(): ${apiURL}`);

  try {
    const response = await fetch(apiURL);
    if (!response.ok) {
      throw new Error(`[ERROR] Failed to fetch full script. Status: ${response.status}`);
    }
    const data = await response.json();
    const decoded = atob(data.content);
    return decoded;
  } catch (err) {
    console.error(err);
    return 'Unable to load full script.';
  }
}

let cachedReadmeHTML = null; // cache so we only parse once

async function getRepositoryReadmeHTML() {
  if (cachedReadmeHTML) return cachedReadmeHTML;

  const readmeApiUrl = `${baseApiURL}/README.md`;
  try {
    const response = await fetch(readmeApiUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch README. Status: ${response.status}`);
    }
    const data = await response.json();
    const decoded = atob(data.content);

    // Turn the Markdown into highlighted HTML
    const finalHTML = parseMarkdownWithPrism(decoded);
    cachedReadmeHTML = finalHTML;
    return finalHTML;
  } catch (err) {
    console.error(err);
    return '<p>Unable to load README.md.</p>';
  }
}

/*************************************************************************
 * Creating Each Script Block
 *************************************************************************/
function createScriptBlock(folder, file) {
  // Determine raw GitHub URL
  const filePath = folder ? `${folder}/${file}` : file;
  const fileURL = `${baseRawURL}/${filePath}`;
  const command = `bash -c "$(wget -qLO - ${fileURL})"`;
  const formattedName = formatFileName(file);

  // Unique IDs for .info-button and .script-button sections
  const infoId = `info-${filePath.replace(/[\/.]/g, '-')}`;
  const fullScriptId = `full-${filePath.replace(/[\/.]/g, '-')}`;

  // Create container
  const container = document.createElement('div');
  container.classList.add('file-block');

  // Build inner HTML
  container.innerHTML = `
    <pre>
      <span class="file-name">${formattedName}</span>
      <code>${command}</code>
      <div class="file-footer">
        <button class="copy-button">Copy Command</button>
        <button class="info-button">Show Info</button>
        <button class="script-button">Show Full Script</button>
      </div>
      <div class="file-info hidden" id="${infoId}"></div>
      <div class="full-script hidden" id="${fullScriptId}"></div>
    </pre>
  `;

  // Attach direct event listeners for each button
  const copyBtn = container.querySelector('.copy-button');
  const infoBtn = container.querySelector('.info-button');
  const scriptBtn = container.querySelector('.script-button');
  const infoDiv = container.querySelector(`#${infoId}`);
  const fullDiv = container.querySelector(`#${fullScriptId}`);

  // 1) Copy Command Logic
  copyBtn.addEventListener('click', () => {
    console.log('[DEBUG] Copy button clicked:', command);
    navigator.clipboard.writeText(command);
    copyBtn.textContent = 'Copied!';
    setTimeout(() => (copyBtn.textContent = 'Copy Command'), 2000);
  });

  // 2) Show/Hide Info
  infoBtn.addEventListener('click', async () => {
    const isHidden = infoDiv.classList.contains('hidden');
    console.log(`[DEBUG] Info button clicked. isHidden=${isHidden}`);
    if (isHidden) {
      // Show info
      infoBtn.textContent = 'Hide Info';
      infoDiv.classList.remove('hidden');

      // Only fetch if not already loaded
      if (!infoDiv.textContent.trim()) {
        const topComment = await fetchTopComment(filePath);
        infoDiv.textContent = topComment;
      }
    } else {
      // Hide info
      infoBtn.textContent = 'Show Info';
      infoDiv.classList.add('hidden');
    }
  });

  // 3) Show/Hide Full Script
  scriptBtn.addEventListener('click', async () => {
    const isHidden = fullDiv.classList.contains('hidden');
    console.log(`[DEBUG] Full script button clicked. isHidden=${isHidden}`);
    if (isHidden) {
      // Show script
      scriptBtn.textContent = 'Hide Full Script';
      fullDiv.classList.remove('hidden');

      // Only fetch if not already loaded
      if (!fullDiv.textContent.trim()) {
        const content = await fetchFullScript(filePath);
        // Prism highlight
        const highlighted = Prism.highlight(content, Prism.languages.bash, 'bash');
        fullDiv.innerHTML = `<pre class="language-bash"><code class="language-bash">${highlighted}</code></pre>`;
      }
    } else {
      // Hide script
      scriptBtn.textContent = 'Show Full Script';
      fullDiv.classList.add('hidden');
    }
  });

  return container;
}

function createDownloadRepoBlock() {
    // Command to clone or download the repo
    const command = `git clone https://github.com/coelacant1/ProxmoxScripts.git`;
  
    // Create a container
    const container = document.createElement('div');
    container.classList.add('file-block'); // Reuse your .file-block styling if desired
  
    // Set up the innerHTML with explicit block-level elements
    container.innerHTML = `
      <div class="download-repo-title">Download Repository</div>
      <div class="code-block">
        <pre><code>${command}</code></pre>
      </div>
      <div class="file-footer">
        <button class="copy-button">Copy Command</button>
      </div>
    `;
  
    // Attach a direct event listener for the copy button
    const copyBtn = container.querySelector('.copy-button');
    copyBtn.addEventListener('click', () => {
      navigator.clipboard.writeText(command);
      copyBtn.textContent = 'Copied!';
      setTimeout(() => (copyBtn.textContent = 'Copy Command'), 2000);
    });
  
    return container;
  }
  
  

/*************************************************************************
 * Fetching Directory Structure & Rendering
 *************************************************************************/
async function fetchRepoStructure(path = '') {
  const apiURL = `${baseApiURL}/${path}`;
  console.log(`[DEBUG] fetchRepoStructure(): ${apiURL}`);
  try {
    const res = await fetch(apiURL);
    if (!res.ok) throw new Error(`[ERROR] Failed to fetch directory. Status: ${res.status}`);
    return await res.json();
  } catch (err) {
    console.error(err);
    return [];
  }
}

/**
 * Convert Markdown to HTML and run Prism on any code blocks
 * @param {string} markdown Raw README.md text
 * @returns {string} HTML string (already code-highlighted)
 */
function parseMarkdownWithPrism(markdown) {
    // Convert Markdown to HTML (using Marked or your chosen Markdown parser)
    const html = marked.parse(markdown);
  
    // Create a temporary container to apply Prism highlighting
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;
  
    // Highlight each code block with Prism
    tempDiv.querySelectorAll('pre code').forEach((codeBlock) => {
      Prism.highlightElement(codeBlock);
    });
  
    // Return the updated HTML
    return tempDiv.innerHTML;
  }
  

async function showRepositoryReadme() {
// This function is presumably called in `renderContent()` or similar
const readmeContainer = document.createElement('div');
readmeContainer.classList.add('file-info'); // or similar styling

const readmeHTML = await getRepositoryReadmeHTML();
readmeContainer.innerHTML = readmeHTML;  // directly set the HTML

return readmeContainer;
}

// Render the root or any subfolder
async function renderContent(path = '') {
  console.log(`[DEBUG] renderContent(): path="${path}"`);
  const contents = await fetchRepoStructure(path);
  console.log('[DEBUG] Directory contents:', contents);

  // Clear current content
  content.innerHTML = '';

  // Filter out hidden items (starting with .)
  const visibleItems = contents.filter((item) => !item.name.startsWith('.'));

  // Sort: dirs first, files second
  visibleItems.sort((a, b) => {
    if (a.type === b.type) return a.name.localeCompare(b.name);
    return a.type === 'dir' ? -1 : 1;
  });

  // Create a simple list
  const list = document.createElement('ul');

  // If not root, add a back link
  if (path) {
    const parentPath = path.split('/').slice(0, -1).join('/');
    const backItem = document.createElement('li');
    backItem.innerHTML = `<a href="#" class="back-link">../</a>`;
    backItem.querySelector('a').addEventListener('click', () => {
      renderContent(parentPath);
    });
    list.appendChild(backItem);
  }

  // Populate folders/files
  for (const item of visibleItems) {
    if (item.type === 'dir') {
      // Folder
      const li = document.createElement('li');
      li.innerHTML = `<a href="#" class="folder-link">${item.name}</a>`;
      li.querySelector('a').addEventListener('click', () => {
        renderContent(path ? `${path}/${item.name}` : item.name);
      });
      list.appendChild(li);
    } else if (item.type === 'file' && item.name.endsWith('.sh')) {
      // Script
      const li = document.createElement('li');
      const block = createScriptBlock(path, item.name);
      li.appendChild(block);
      list.appendChild(li);
    }
  }

  content.appendChild(list);

  if (!path) {
    // we are at root, so show the "Download Repository" block
    const downloadBlock = createDownloadRepoBlock();
    content.appendChild(downloadBlock);
  }

  // near the end of renderContent()
  const readmeDiv = await showRepositoryReadme();
  content.appendChild(readmeDiv);

}

/*************************************************************************
 * On Page Load
 *************************************************************************/
document.addEventListener('DOMContentLoaded', () => {
  renderContent(); // Render root directory
});
