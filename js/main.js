import 'lit-toast';

// Put utilities on the window for debugging.
import * as util from './util.js';
window.util = util;

import './theme-switch.js';
import './login-pane.js';
import './comment-section.js';
import './recent-comments.js';
import './auth-popup.js';
import './notifs-panel.js';
import './spem-search.js';

// Apply saved theme.
const currentTheme = localStorage.getItem('theme');
if (currentTheme) document.documentElement.setAttribute('data-theme', currentTheme);

// Put a global reference to the article timestamp.
addEventListener('load', () => {
	window.timestr = document.getElementById('timestamp').getAttribute('datetime');
	window.timestamp = new Date(window.timestr);
});
