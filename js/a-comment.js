import {LitElement, html, css} from 'lit-element';
import {unsafeHTML} from 'lit-html/directives/unsafe-html.js';

import * as util from './util.js';
import {styles} from './css.js';

customElements.define('a-comment', class extends LitElement {
	static get properties() {
		return {
			comment: {type: Object},
			loggedIn: {type: Boolean},
			key: {type: Boolean},
			admin: {type: Boolean},
			replyOpen: {type: Boolean},
			editMode: {type: Boolean},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host { display: block; }
		.comment {
			border: 1px solid var(--weakcolor);
			border-radius: 6px;
			margin-top: 0.5em;
			margin-bottom: 0.5em;
			box-shadow: 0px 0px 4px 0px var(--weakcolor);
		}
		.header {
			padding: 0.5em;
			overflow-x: auto;
			display: flex;
			width: 100%;
			justify-content: space-between;
		}
		.meta {
			display: flex;
			flex-direction: column;
			justify-content: left;
		}
		.body {
			padding: 0.5em;
			overflow-x: auto;
		}
		.body p {
			white-space: pre-line;
		}
		hr {
			margin-top: 0;
			margin-bottom: 0;
		}
		comment-submit-area {
			margin-left: 1em;
		}
		`];
	}
	constructor() {
		super();
		this.loggedIn = util.readCookie('auth') && util.readCookie('email');
		this.admin = util.readCookie('admin');
		this.replies = [];
	}
	render() {
		return html`
		<div class="comment">
			<div class="header">${this.renderHeader()}</div>
			<hr>
			${this.editMode? html`
				<textarea id="body" @input="${util.autogrow}">${this.comment.body}</textarea>
			`:html`
				<div class="body" id="body">${unsafeHTML(this.comment.body)}</div>
			`}
			<hr>
			<button @click="${() => this.replyOpen = true}">Reply</button>
			<a href="${location.origin + location.pathname}?c=${this.comment.id}#comment-section">
				view subtree
				<!-- if the replies weren't returned, the property is a count of them -->
				${typeof this.comment.replies === 'number' && this.comment.replies?
					"(more replies)"
				:''}
			</a>
		</div>
		${this.replyOpen? html`
			<comment-submit-area reply-to="${this.comment.id}" ?logged-in="${this.loggedIn}">
			</comment-submit-area>
		`:''}
		<div class="indent">
			${this.comment.replies instanceof Array?
				this.comment.replies.map(c => html`<a-comment .comment="${c}"></a-comment>`)
			:''}
		</div>
		`;
	}
	renderHeader() {
		return html`
		<div class="meta">
			${this.editMode? html`
				<input id="name" value="${this.comment.name}">
			`:html`
				<b id="name"
					style="${this.comment.admin? 'color:var(--yellowcolor)' : ''}"
					title="${this.comment.admin? 'admin' : ''}">
					${this.comment.name}
				</b>
			`}
			<small>
				<span style="${new Date(this.comment.time_added) < window.timestamp? 'color:orange' : ''}">
					${util.formatDate(this.comment.time_added)}
				</span>
				${this.comment.time_changed? html`
					- <span style="color:orange">edited ${util.formatDate(this.comment.time_changed)}</span>
				`:''}
			</small>
		</div>
		${this.loggedIn? html`
			<div class="actions">${this.renderActions()}</div>
		`:''}
		`;
	}
	renderActions() {
		return html`
		${this.comment.sub == null? html`
			<button @click="${() => this.setNotifs(true)}">Subscribe</button>
			<button @click="${() => this.setNotifs(false)}">Ignore</button>
		`:''}
		${this.comment.sub == true? html`
			<button @click="${() => this.setNotifs(null)}">Unsubscribe</button>
			<button @click="${() => this.setNotifs(false)}">Ignore</button>
		`:''}
		${this.comment.sub == false? html`
			<button @click="${() => this.setNotifs(true)}">Subscribe</button>
			<button @click="${() => this.setNotifs(null)}">Unignore</button>
		`:''}
		${this.admin || this.comment.owned? html`
			${this.editMode? html`
				<button @click="${this.finishEdit}">Save</button>
			`:html`
				<button @click="${this.edit}">Edit</button>
			`}
		`:''}
		${this.admin? html`
			<button @click="${this.delete}">Delete</button>
		`:''}
		`;
	}
	async setNotifs(state) {
		await util.api('PUT', 'users/notifs', undefined, {id: this.comment.id, state: state});
		this.comment.sub = state;
		this.requestUpdate();
	}
	async edit() {
		const resp = await util.api('GET', 'comments', {id: this.comment.id, raw: true});
		this.comment.body = resp.comments[0].body;
		this.editMode = true;
	}
	async finishEdit() {
		await util.api('PUT', 'comments', undefined, {
			id: this.comment.id,
			name: this.shadowRoot.getElementById('name').value,
			body: this.shadowRoot.getElementById('body').value,
		});
		this.editMode = false;
		// Re-fetch it.
		this.comment = (await util.api('GET', 'comments', {id: this.comment.id})).comments[0];
	}
	async delete() {
		await util.api('DELETE', `comments/${this.comment.id}`);
		this.remove();
	}
});
