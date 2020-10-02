import {LitElement, html, css} from 'lit-element';
import './login-pane.js';

import * as util from './util.js';
import {styles} from './css.js';

customElements.define('notifs-panel', class extends LitElement {
	static get properties() {
		return {
			email: {type: String, attribute: false},
			user: {type: String, attribute: false},
			commentSubs: {type: Array, attribute: false},
			articleSubs: {type: Array, attribute: false},
			autosub: {type: Boolean, attribute: false},
			subSite: {type: Boolean, attribute: false},
			disableReset: {type: Boolean, attribute: false},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host { display: block; }
		fieldset {
		    border: 1px solid var(--weakcolor);
		    border-radius: 4px;
		}
		`];
	}
	constructor() {
		super();
		this.email = util.readCookie('email');
		this.name = util.readCookie('name');
		this.key = util.readCookie('key');
		this.subs = [];
		if (!util.readCookie('auth')) {
			this.setAttribute('hidden', 'true');
			return addEventListener('load', async () => {
				await util.login();
				location.reload();
			});
		}
		this.fetchData();
	}
	render() {
		return html`
		<login-pane no-settings-link></login-pane>
		<fieldset>
			<label for="pw">password:</label>
			<input type="text" id="pw">
			<button @click="${this.setPw}">submit</button>
		</fieldset>
		${this.key ? html`
			<br>
			<fieldset>
				<p>
				Now that you've set a key, you can claim your name, preventing others from
				commenting as it.
				</p>
				<label for="name">name:</label>
				<input type="text" id="name" placeholder="${this.name}">
				<button @click="${this.setName}">submit</button>
			</fieldset>
		`:''}
		<p>
		Normally, you get notifications for replies to any comment you're subscribed
		to or are subscribed to a parent of. Setting a comment to "ignore" will prevent
		you receiving notifications even if you're subscribed to a parent of it.
		Basically, it travels up the tree and obeys the first subscription or ignore it finds.
		</p>
		<input id="autosub" type="checkbox" ?checked="${this.autosub}" @change="${this.setAutosub}"></input>
		<label for="autosub">Automatically subscribe to your own comments</label>
		<br>
		<input id="sub-site" type="checkbox" ?checked="${this.subSite}" @change="${this.setSubSite}"></input>
		<label for="sub-site">Be notified when new articles are posted</label>
		<br>
		<input id="disable-reset" type="checkbox" ?checked="${this.disableReset}" @change="${this.setDisableReset}"></input>
		<label for="disable-reset">Disable password reset emails (a security feature)</label>
		<h3>Subscriptions</h3>
		<table>
			<thead><tr>
			<td>Comment/Article</td>
			<td>Actions</td>
			</tr></thead>
			<tbody id="subs">
				${this.articleSubs.map(s => html`
				<tr>
					<td><a href="${s.path}">${s.title}</a></td>
					<td>
					<button @click="${() => this.delArticleSub(s.path)}">clear</button>
					</td>
				</tr>
				`)}
				${this.commentSubs.filter(s => s.sub).map(s => html`
				<tr>
					<td>${util.summarizeComment(s.comment)}</td>
					<td>
					<button @click="${() => this.editCommentSub(s.comment.id, null)}">clear</button>
					<button @click="${() => this.editCommentSub(s.comment.id, false)}">ignore</button>
					</td>
				</tr>
				`)}
			</tbody>
		</table>
		<h3>Ignores</h3>
		<table>
			<thead><tr>
			<td>Comment</td>
			<td>Actions</td>
			</tr></thead>
			<tbody id="ignores">
				${this.commentSubs.filter(s => !s.sub).map(s => html`
				<tr>
					<td>${util.summarizeComment(s.comment)}</td>
					<td>
					<button @click="${() => this.editCommentSub(s.comment.id, null)}">clear</button>
					<button @click="${() => this.editCommentSub(s.comment.id, true)}">subscribe</button>
					</td>
				</tr>
				`)}
			</tbody>
		</table>
		`;
	}
	async fetchData() {
		const data = await util.api('GET', 'users/notifs');
		this.commentSubs = data.comment_subs;
		this.articleSubs = data.article_subs;
		this.autosub = data.autosub;
		this.subSite = data.site;
		this.disableReset = data.disable_reset;
	}
	async setPw() {
		const pwBox = this.shadowRoot.getElementById('pw');
		await util.api('PUT', 'users/pw', undefined, pwBox.value);
		util.showToast('success', "Password set.");
		pwBox.value = '';
	}
	async setName() {
		const nameBox = this.shadowRoot.getElementById('name');
		await util.api('PUT', 'users/name', undefined, nameBox.value);
		util.showToast('success', "Name set.");
		nameBox.placeholder = nameBox.value;
		nameBox.value = '';
	}
	async setKey() {
		const keyFile = this.shadowRoot.getElementById('key').files[0];
		await util.api('PUT', 'users/setkey', undefined, await keyFile.text());
		location.reload();
	}
	async setAutosub(e) {
		await util.api('PUT', 'users/autosub', undefined, e.target.checked);
		util.showToast('success', "Setting saved");
	}
	async setSubSite(e) {
		await util.api('PUT', 'users/subsite', undefined, e.target.checked);
		util.showToast('success', "Setting saved");
	}
	async setDisableReset(e) {
		await util.api('PUT', 'users/disablereset', undefined, e.target.checked);
		util.showToast('success', "Setting saved");
	}
	async editCommentSub(id, state) {
		await util.api('PUT', 'users/notifs', undefined, {id: id, state: state});
		this.fetchData();
	}
	async delArticleSub(path) {
		await util.api('PUT', 'users/notifs', undefined, {path: path, state: null});
		this.fetchData();
	}
});
