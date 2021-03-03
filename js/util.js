'use strict';

import {unsafeHTML} from 'lit-html/directives/unsafe-html.js';

export async function api(method, url, query, body) {
	if (typeof body == 'object') body = JSON.stringify(body);
	if (query) {
		const params = new URLSearchParams();
		for (const param in query) {
			if (query[param] instanceof Array)
				for (const val of query[param]) params.append(param, val);
			else if (query[param] != null) params.append(param, query[param]);
		}
		url += `?${params.toString()}`;
	}
	try {
		var resp = await fetch('/api/' + url, {body: body, method: method,
			headers: {'Content-Type': "application/json"}});
	} catch (err) {
		showToast('err', "Failed to send request");
		throw err;
	}
	// Don't try to recursively make the login request. Let the auth popup handle retries.
	if (url == 'users/login') return resp;
	if (resp.status == 401) {
		// Set this flag for callers who want to know whether the request required login.
		window.loginRequired = true;
		await login(await resp.text());
		return api(method, url, undefined, body);
	} else if (!resp.ok) {
		throw handleErr(resp);
	}
	if (resp.headers.get('Content-Type') === 'application/json' && !(resp.headers.get('Content-Length') == 0))
		return await resp.json();
	return await resp.text();
}

const errorCodes = {
	400: "Bad request",
	401: "Not logged in?",
	403: "You don't have permission to do that.",
	404: "Not found",
	500: "Server error. I should receive an automatic email about this, so I'll probably fix it soon.",
	502: "Seems like the server isn't running. Hopefully I'll fix this ASAP.",
}

export const login = (initialMsg) => document.querySelector('auth-popup').run(initialMsg);

export async function handleErr(resp) {
	// Check for a message from the server.
	var text = await resp.text();
	if (!text || text.includes("<html")) // Don't display HTML responses.
		text = errorCodes[resp.status] || `Error ${resp.status}`;
	showToast('err', text);
}

// This function is taken from W3Schools.
export function readCookie(cname) {
	var name = cname + "=";
	var decodedCookie = decodeURIComponent(document.cookie);
	var cookies = decodedCookie.split(';');
	for (let i = 0; i < cookies.length; i++) {
		let c = cookies[i];
		while (c.charAt(0) == ' ') {
			c = c.substring(1);
		}
		if (c.indexOf(name) == 0) {
			return c.substring(name.length, c.length);
		}
	}
	return "";
}

// Gives them a month.
export function setCookie(name, val) {
	document.cookie = `${name}=${val}; path=/; max-age=2592000;`;
}

// Helper to format a comment's metadata as a sentence.
export function summarizeComment(comment) {
	return unsafeHTML(`${comment.name} on
		<a href="${comment.link}">${comment.article_title}</a>
		at ${formatDate(comment.time_added)}`);
}

// Used for pages that have a column layout.
window.resizeColumns = function() {
	// Get the grid and columns.
	const grid = document.getElementsByClassName('row')[0];
	const columns = document.getElementsByClassName("column");
	// Shortcut.
	let gridStyle = getComputedStyle(grid);
	// Get the grid width in em.
	const emSize = parseFloat(gridStyle['font-size']);
	const width = parseInt(gridStyle.width) / emSize;
	// Just get any colunm's minimum width since they'll be the same.
	const minColWidth = parseFloat(
		parseInt(getComputedStyle(columns[0]).minWidth) +
		parseInt(gridStyle.gridRowGap)) / emSize;
	while (true) {
		// Count the current columns the grid is set to.
		let colsPerRow = gridStyle.gridTemplateColumns.split(' ').length;
		// If we need to add a row, do so.
		if (width / colsPerRow < minColWidth) {
			// Emergency stop if we would try to go down to 0 columns.
			if (colsPerRow <= 1) break;
			// TODO I think this overcompresses with >= 7 columns.
			grid.style["grid-template-columns"] = 'repeat(' + Math.ceil(colsPerRow / 2) + ', 1fr)';
		// If we can eliminate a row, do so.
		} else {
			// Find the number of columns in the bottom row.
			let bottomCols = columns.length % colsPerRow || colsPerRow;
			// Find the number of rows above it.
			let rowsAbove = (columns.length - bottomCols) / colsPerRow;
			// Calculate the max number of colums we could need to add.
			let maxAddition = Math.ceil(bottomCols / rowsAbove);
			// Calculate the required width.
			let reqWidth = minColWidth * (colsPerRow + maxAddition);
			// If we have it, cut the bottom row.
			if (reqWidth <= width) {
				grid.style["grid-template-columns"] = 'repeat(' + (colsPerRow + maxAddition) + ', 1fr)';
			} else {
				break;
			}
		}
	}
};

export function showToast(tone, msg) {
	// This flag is set when navigating away to stop error toasts from firing.
	if (window.noShowError) return;
	// If there's already a toast, remove it. We can't reuse it because re-calling show doesn't update the text.
	let toast = document.querySelector('lit-toast');
	if (toast) toast.remove();
	toast = document.createElement('lit-toast');
	document.body.appendChild(toast);
	const color = {'err': '#f00', 'success': '#0f0'}[tone];
	toast.setAttribute('style', `--lt-color:${color};`)
	toast.show(msg);
}

// parse a query string into an object with duplicate keys represented as arrays.
export function parseQuery(queryString) {
	const query = {};
	for (const [param, value] of new URLSearchParams(queryString).entries())
		if (query[param] == undefined) {
			query[param] = value;
		} else if (query[param] instanceof Array) {
			query[param].push(value);
		} else {
			query[param] = [query[param], value];
		}
	return query;
}

// This flag stops error toasts from showing when a request is interrupted by navigating away.
addEventListener("beforeunload", () => window.noShowError = true);

// A global utility to make a textarea grow when necessary.
export function autogrow(e) {
	const textarea = e.target;
	// Temporarily add a bottom margin equal to the height of the textarea.
	// This prevents a glitch that scrolls the viewport upward when the textarea contracts.
	const prevMarginBottom = textarea.style.marginBottom;
	textarea.style.marginBottom = textarea.scrollHeight + 'px';
	// We have to clear the height first so it can also shrink when text is deleted.
	textarea.style.height = 'inherit';
	textarea.style.height = textarea.scrollHeight + 2 + 'px';
	textarea.style.marginBottom = prevMarginBottom;
}

// Takes a number and pads its string representation to 2 digits.
export function leftpad(num) {
	if (num >= 10) return String(num);
	return '0' + num;
}

export function formatDate(d) {
	d = new Date(d); // Incase it's in string form. This won't change the value of a Date object.
	return `${d.getUTCFullYear()}-${leftpad(d.getMonth()+1)}-${leftpad(d.getDate())}
		${leftpad(d.getHours())}:${leftpad(d.getMinutes())}`;
}
