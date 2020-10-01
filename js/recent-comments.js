import {LitElement, html, css} from 'lit-element';

import * as util from './util.js';
import {styles} from './css.js';

customElements.define('recent-comments', class extends LitElement {
	static get properties() {
		return {
			comments: {type: Array, attribute: false},
		}
	}
	static get styles() {
		return [styles, css`
		:host([hidden]) { display: none; }
		:host { display: block; }
		* {
			overflow-wrap: break-word;
		}
		`];
	}
	constructor() {
		super()
		this.count = 10;
	}
	render() {
		return html`
		<h2>Recent comments</h2>
		<div id="comments">
			${this.comments?
				this.comments.map(c => html`<p>${util.summarizeComment(c)}</p>`)
				: "Loading..."
			}
		</div>
		<button @click="${this.loadMore}">Load 5 more</button>
		`;
	}
	firstUpdated() {
		super.firstUpdated();
		this.load();
	}
	async load() {
		this.comments = await util.api('GET', 'comments/recent', {count: this.count});
	}
	loadMore() {
		this.count += 5;
		this.load();
	}
});
