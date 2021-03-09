import {LitElement, html, css} from 'lit-element';

import './a-comment.js';
import './comment-submit-area.js';
import './login-pane.js';
import * as util from './util.js';
import {styles} from './css.js';

customElements.define('comment-section', class extends LitElement {
	static get properties() {
		return {
			loggedIn: {type: String, attribute: false},
			subscribed: {type: Boolean, attribute: false},
			admin: {type: Boolean, attribute: false},
			comments: {type: Array, attribute: false},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host { display: block; }
		`];
	}
	constructor() {
		super();
		this.loggedIn = util.readCookie('auth') && util.readCookie('email');
		this.admin = util.readCookie('admin');
		this.comments = [];
		this.loadComments();
		this.addEventListener('comment-posted', this.loadComments);
	}
	render() {
		return html`
		<h1>Comments</h1>
		<p>
		You can post without an account; if you provide an email, an account will be created and a confirmation email
		sent. Accounts provide reply notifications and the ability to edit your comments.
		</p><p>
		Formatting with <a href="https://yujiri.xyz/sanemark">Sanemark</a>, a version of Markdown, is supported.
		</p><p>
		Comments made before the page's modification timestamp have orange timestamps.
		</p>
		<login-pane></login-pane>
		<br>
		${this.loggedIn? html`
			<label for="sub-post">Be notified of new top-level comments on this page</label>
			<input id="sub-post" type="checkbox" ?checked="${this.subscribed}" @change="${this.toggleSubscribe}">
		`:''}
		<comment-submit-area open ?logged-in="${this.loggedIn}" reply-to="${location.pathname}">
		</comment-submit-area>
		${util.parseQuery(location.search).c? html`
			You're viewing a subtree of the comments.
			${this.comments[0] && this.comments[0].reply_to? html`
				<a href="${location.origin + location.pathname}?c=${
					this.comments[0].reply_to}#comment-section">view parent</a> or
			`:''}
			<a href="${location.origin + location.pathname}#comment-section">
				view all comments on this page</a>
		`:''}
		<div id="comments">
			${this.comments.map(c => html`<a-comment .comment="${c}"></a-comment>`)}
		</div>
		`;
	}
	async loadComments() {
		const subtree = util.parseQuery(location.search).c;
		const data = await util.api('GET', 'comments', subtree?
			{id: subtree} : {article_path: location.pathname}
		);
		this.comments = data.comments;
		this.subscribed = data.article_sub;
	}
	async toggleSubscribe(e) {
		await util.api('PUT', 'users/notifs', undefined, {path: location.pathname, state: e.target.checked});
		util.showToast('success', "Setting saved");
	}
});

