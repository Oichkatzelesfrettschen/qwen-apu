/* What a turn carries beside its prompt: the files the reader attached, their
   token counts, and the image data URLs a vision model reads.

   One selection belongs to one model and one conversation across every file
   read, so each attachment records the model its count was measured under and
   a model change marks every count pending rather than carrying a stale one
   forward. An image attachment is admitted against the registry's own
   projector pairing before its bytes are read, because a checkpoint published
   without a projector reads image tokens as nothing and answers wrongly rather
   than failing.

   The array is a `const` the whole page shares. `send()` empties it with
   `length = 0` rather than rebinding it, so every module reads one array. */

import { $, serverTokenCount } from './api.js';
import {
  modelPropertiesForSelection,
  modelState,
  modelStateMatches
} from './models.js';
import { conversationState } from './conversations.js';

// {name, kind, text, tokens, tokenModel} for a text file; {name, kind, mime,
// dataUrl, tokens, tokenModel} for an image.
export const attachments = [];

export function chip(text, over, onRemove) {
  const c = document.createElement('span');
  c.className = 'chip' + (over ? ' over' : '');
  c.append(text);
  const b = document.createElement('button');
  b.textContent = 'remove';
  b.onclick = onRemove;
  c.append(b);
  return c;
}

export function renderAttached() {
  const box = $('#attached');
  box.textContent = '';
  let total = 0;
  let countsComplete = true;
  attachments.forEach(attachment => {
    if (attachment.kind === 'image') return;
    if (attachment.tokenModel === modelState.requestModel &&
        Number.isInteger(attachment.tokens)) total += attachment.tokens;
    else countsComplete = false;
  });
  const contextReady = modelState.nctxModel === modelState.requestModel && Number.isFinite(modelState.nctx);
  attachments.forEach((a, i) => {
    if (a.kind === 'image') {
      box.append(chip(`${a.name} -- image for ${modelState.requestModel}`, false,
        () => { attachments.splice(i, 1); renderAttached(); }));
      return;
    }
    const countReady = a.tokenModel === modelState.requestModel && Number.isInteger(a.tokens);
    const countText = countReady
      ? `${a.tokens.toLocaleString()} tokens`
      : a.tokenModel === modelState.requestModel ? 'token count unavailable' : 'token count pending';
    const over = countsComplete && contextReady && total > modelState.nctx * 0.9;
    box.append(chip(
      `${a.name} -- ${countText}`,
      over, () => { attachments.splice(i, 1); renderAttached(); }));
  });
  const textAttachmentCount = attachments.filter(attachment => attachment.kind !== 'image').length;
  if (textAttachmentCount && !countsComplete) {
    const w = document.createElement('span');
    w.className = 'chip over';
    w.textContent = 'token counts remain unavailable for the selected model; context fit is unknown';
    box.append(w);
  } else if (textAttachmentCount && contextReady && total > modelState.nctx * 0.9) {
    const w = document.createElement('span');
    w.className = 'chip over';
    w.textContent = `about ${total.toLocaleString()} tokens against a ${modelState.nctx.toLocaleString()} context; the server will refuse this with a 400`;
    box.append(w);
  }
}

export async function selectedModelAcceptsImages(
  expectedModel, expectedConversationGeneration, expectedModelGeneration
) {
  if (!expectedModel || !modelStateMatches(expectedModel, expectedModelGeneration) ||
      conversationState.generation !== expectedConversationGeneration) {
    return { state: 'stale' };
  }
  const result = await modelPropertiesForSelection(expectedModel, expectedModelGeneration);
  if (!modelStateMatches(expectedModel, expectedModelGeneration) ||
      conversationState.generation !== expectedConversationGeneration || result.state === 'stale') {
    return { state: 'stale' };
  }
  if (result.state === 'unavailable') return result;
  return result.props && result.props.modalities && result.props.modalities.vision === true
    ? { state: 'supported' }
    : { state: 'unsupported' };
}

export function imageFileDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => typeof reader.result === 'string'
      ? resolve(reader.result) : reject(new Error('the image reader returned no data URL'));
    reader.onerror = () => reject(reader.error || new Error('the image could not be read'));
    reader.readAsDataURL(file);
  });
}

export function composeUserContent(text, attached) {
  let prompt = text;
  for (const file of attached.filter(attachment => attachment.kind !== 'image')) {
    prompt = `--- ${file.name} ---\n${file.text}\n--- end ${file.name} ---\n\n` + prompt;
  }
  const images = attached.filter(attachment => attachment.kind === 'image');
  return {
    prompt,
    images,
    content: images.length ? [
      { type: 'text', text: prompt || 'Describe the attached image.' },
      ...images.map(attachment => ({
        type: 'image_url', image_url: { url: attachment.dataUrl }
      }))
    ] : prompt
  };
}

export async function attachFiles(files) {
  // One selection belongs to one model and conversation across every file read.
  const attachmentModel = modelState.requestModel;
  const attachmentGeneration = conversationState.generation;
  const attachmentModelGeneration = modelState.generation;
  const selectionIsCurrent = () => modelState.requestModel === attachmentModel &&
    conversationState.generation === attachmentGeneration &&
    modelState.generation === attachmentModelGeneration;
  for (const file of Array.from(files)) {
    if (!selectionIsCurrent()) break;
    try {
      if (typeof file.type === 'string' && file.type.startsWith('image/')) {
        const capability = await selectedModelAcceptsImages(
          attachmentModel, attachmentGeneration, attachmentModelGeneration);
        if (capability.state === 'stale' || !selectionIsCurrent()) break;
        if (capability.state === 'unsupported') {
          throw new Error(`model ${modelState.requestModel || '(none)'} does not report vision capability`);
        }
        if (capability.state === 'unavailable') {
          throw new Error(`could not verify model vision capability: ${capability.detail}`);
        }
        const dataUrl = await imageFileDataUrl(file);
        if (!selectionIsCurrent()) break;
        attachments.push({ name: file.name, kind: 'image', mime: file.type, dataUrl,
                           tokens: null, tokenModel: attachmentModel });
      } else {
        const text = await file.text();
        if (!selectionIsCurrent()) break;
        if (!attachmentModel) throw new Error('no routable model is selected');
        const tokens = await serverTokenCount(text, attachmentModel);
        if (!selectionIsCurrent()) break;
        attachments.push({ name: file.name, kind: 'text', text, tokens,
                           tokenModel: attachmentModel });
      }
    } catch (error) {
      if (!selectionIsCurrent()) break;
      window.alert(`Could not attach ${file.name}: ${error.message || error}`);
    }
  }
  renderAttached();
}



export function initAttachments() {
  $('#file').onchange = async event => {
    await attachFiles(event.target.files);
    event.target.value = '';
  };
}
