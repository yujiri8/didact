import {LitElement, html, css} from 'lit-element';
import {unsafeHTML} from 'lit-html/directives/unsafe-html.js';

import * as util from './util.js';
import {styles} from './css.js';

customElements.define('comment-submit-area', class extends LitElement {
	static get properties() {
		return {
			replyTo: {type: Number, attribute: 'reply-to'},
			loggedIn: {type: Boolean, attribute: 'logged-in'},
			previewHTML: {type: String, attribute: false},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host {	display: block; }
		.meta {
			float: left;
		}
		.actions {
			float: right;
		}
		hr {
			margin-top: 0;
			margin-bottom: 0;
		}
		#preview {
			border: 1px solid var(--weakcolor);
			padding: 2px;
		}
		`];
	}
	connectedCallback() {
		super.connectedCallback();
		this.savedContents = localStorage.getItem(`reply_${this.replyTo}`) || '';
	}
	render() {
		return html`
		<button @click="${this.submit}">Submit</button>
		${this.previewHTML? html`
			<button @click="${this.unpreview}">Edit</button>
		`:html`
			<button @click="${this.preview}">Preview</button>
		`}
		<br>
		<label for="name">Name:</label>
		<input id="name">
		${!this.loggedIn ? html`
			<br>
			<label for="email">Email (optional):</label>
			<input id="email">
			<br>
			<input id="sub-site" type="checkbox">
			<label for="sub-site">
				Be notified of new articles (more sophisticated subscription settings available in account settings)
			</label>
		`:''}
		<br>
		${this.previewHTML? html`
			<div id="preview">${unsafeHTML(this.previewHTML)}</div>
		`:html`
			<textarea id="body" @input="${this.autosave}"
				placeholder="Your comment...">${this.savedContents}</textarea>
		`}
		`;
	}
	async submit() {
		if (this.previewHTML) await this.unpreview();
		const nameElem = this.shadowRoot.getElementById('name');
		const emailElem = this.shadowRoot.getElementById('email');
		const bodyElem = this.shadowRoot.getElementById('body');
		// Set the email cookie before sending the request, so it will be filled in if login is required.
		if (emailElem) util.setCookie('email', emailElem.value);
		// Store whether they had to log in, as that means it was an existing account and we
		// shouldn't tell them they'll receive a confirmation email (the auth form will set
		// this to true if it appears).
		window.loginRequired = false;
		await util.api('POST', 'comments', undefined, {
			name: nameElem.value,
			...emailElem && {email: emailElem.value},
			reply_to: this.replyTo,
			article_path: location.pathname,
			body: bodyElem.value,
			...!this.loggedIn && {sub_site: this.shadowRoot.getElementById('sub-site').checked},
		});
		// Now that the comment is posted, clear the autosave.
		localStorage.removeItem(`reply_${this.replyTo}`);
		// Dispatch the event to load the comment in.
		this.dispatchEvent(new CustomEvent('comment-posted',
			{bubbles: true, composed: true, detail: this.replyTo}));
		// Show a toast if it was a new poster making an account.
		if (emailElem && emailElem.value && !window.loginRequired)
			util.showToast('success', "You'll receive a confirmation email about your account creation.");
		// Close the submit area if it's not the top-level one.
		if (this.replyTo) this.remove();
		// Otherwise, just clear the fields.
		else {
			nameElem.value = bodyElem.value = '';
			if (emailElem) emailElem.value = '';
		}
	}
	async preview() {
		this.savedContents = this.shadowRoot.getElementById('body').value;
		const resp = await util.api('POST', 'comments/preview', undefined, this.savedContents);
		try {
			this.previewHTML = await resp.text();
		} catch (err) {
			return util.showToast('err', "Couldn't read response from server");
		}
	}
	async unpreview() {
		this.previewHTML = '';
		await this.updateComplete;
		util.autogrow({target: this.shadowRoot.getElementById('body')});
	}
	autosave(e) {
		util.autogrow(e);
		const content = e.target.value;
		if (content) localStorage.setItem(`reply_${this.replyTo}`, content);
		else localStorage.removeItem(`reply_${this.replyTo}`);
	}
});
