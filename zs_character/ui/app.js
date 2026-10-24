(function () {
  const $ = (id) => document.getElementById(id);
  const resource = 'zs_character';

  function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({}));
  }

  let S = {};               // Texte
  let chars = [];
  let allowDelete = true;
  let maxChars = 5;
  let limits = { minAge: 18, maxAge: 90 };
  let heightCfg = { min: 0.92, max: 1.08, step: 0.01, default: 1.0 };

  const draft = { gender: 'male', parts: {}, scale: 1.0 };
  let categories = [];
  let step = 1;

  function fmt(str, ...args) {
    let i = 0;
    return str.replace(/%d/g, () => args[i++]);
  }

  function show(id) {
    $('screen-select').classList.toggle('hidden', id !== 'select');
    $('screen-create').classList.toggle('hidden', id !== 'create');
  }

  function setError(message) {
    const el = $('error');
    el.textContent = message || '';
    el.classList.toggle('hidden', !message);
  }

  // ---------------- Auswahl ----------------
  function renderList() {
    const list = $('char-list');
    list.innerHTML = '';
    $('slots').textContent = `${S.slotsFree}: ${Math.max(0, maxChars - chars.length)} / ${maxChars}`;
    $('btn-new').disabled = chars.length >= maxChars;

    if (!chars.length) {
      const li = document.createElement('li');
      li.className = 'muted';
      li.textContent = S.empty;
      list.appendChild(li);
      return;
    }

    chars.forEach((c) => {
      const li = document.createElement('li');
      li.className = 'card';
      const last = c.lastPlayed ? new Date(c.lastPlayed * 1000).toLocaleDateString() : S.never;

      const name = document.createElement('div');
      name.className = 'name';
      name.textContent = `${c.firstname} ${c.lastname}`;
      const meta = document.createElement('div');
      meta.className = 'meta';
      meta.textContent = `${c.age} · ${c.jobLabel || c.job} · ${S.lastPlayed}: ${last}`;
      li.append(name, meta);

      const row = document.createElement('div');
      row.className = 'row';
      const play = document.createElement('button');
      play.className = 'primary';
      play.textContent = S.play;
      play.onclick = (e) => { e.stopPropagation(); post('select', { id: c.id }); };
      row.appendChild(play);

      if (allowDelete) {
        const del = document.createElement('button');
        del.className = 'danger';
        del.textContent = S.delete;
        // Zwei Klicks statt window.confirm (Dialoge werden im Spiel-Browser nicht zuverlaessig angezeigt)
        let armed = false;
        del.onclick = (e) => {
          e.stopPropagation();
          if (!armed) {
            armed = true;
            del.textContent = S.confirmDelete;
            setTimeout(() => { armed = false; del.textContent = S.delete; }, 4000);
            return;
          }
          post('delete', { id: c.id });
        };
        row.appendChild(del);
      }

      li.appendChild(row);
      li.onclick = () => {
        document.querySelectorAll('.card').forEach((x) => x.classList.remove('sel'));
        li.classList.add('sel');
        post('previewCharacter', { id: c.id });
      };
      list.appendChild(li);
    });
  }

  // ---------------- Erstellung ----------------
  function resetDraft() {
    draft.gender = 'male';
    draft.parts = {};
    draft.scale = heightCfg.default;
    $('f-firstname').value = '';
    $('f-lastname').value = '';
    $('f-age').value = 25;
    $('f-description').value = '';
    const h = $('f-height');
    h.min = heightCfg.min; h.max = heightCfg.max; h.step = heightCfg.step; h.value = heightCfg.default;
    $('g-male').classList.add('on');
    $('g-female').classList.remove('on');
    setError('');
    goStep(1);
  }

  function goStep(n) {
    step = n;
    document.querySelectorAll('.step').forEach((el) => el.classList.toggle('hidden', Number(el.dataset.step) !== n));
    document.querySelectorAll('#steps li').forEach((el) => el.classList.toggle('on', Number(el.dataset.step) === n));
    $('btn-next').textContent = n === 3 ? S.finish : S.next;
    $('btn-back').textContent = S.back;
    if (n === 2) loadCategories();
    if (n === 3) renderSummary();
    setError('');
  }

  function loadCategories() {
    post('previewGender', { gender: draft.gender, scale: draft.scale }).then((res) => {
      categories = (res && res.categories) || [];
      renderCategories();
    });
  }

  function renderCategories() {
    const box = $('categories');
    box.innerHTML = '';
    $('no-options').classList.toggle('hidden', categories.length > 0);
    $('no-options').textContent = S.noOptions;

    categories.forEach((cat) => {
      const min = cat.optional ? 0 : 1;
      if (draft.parts[cat.id] === undefined) draft.parts[cat.id] = min;

      const row = document.createElement('div');
      row.className = 'cat';
      const label = document.createElement('span');
      label.className = 'label';
      label.textContent = cat.label;
      const prev = document.createElement('button');
      prev.textContent = '‹';
      const val = document.createElement('span');
      val.className = 'val';
      const next = document.createElement('button');
      next.textContent = '›';

      const refresh = () => { val.textContent = `${draft.parts[cat.id]} / ${cat.count}`; };
      const move = (d) => {
        let v = draft.parts[cat.id] + d;
        if (v > cat.count) v = min;
        if (v < min) v = cat.count;
        draft.parts[cat.id] = v;
        refresh();
        post('previewAppearance', { gender: draft.gender, scale: draft.scale, parts: draft.parts });
      };
      prev.onclick = () => move(-1);
      next.onclick = () => move(1);
      refresh();
      row.append(label, prev, val, next);
      box.appendChild(row);
    });
  }

  function validateIdentity() {
    const f = $('f-firstname').value.trim();
    const l = $('f-lastname').value.trim();
    const a = parseInt($('f-age').value, 10);
    if (f.length < 2 || l.length < 2) { setError(S.errName); return false; }
    if (!(a >= limits.minAge && a <= limits.maxAge)) { setError(fmt(S.errAge, limits.minAge, limits.maxAge)); return false; }
    return true;
  }

  function renderSummary() {
    const dl = $('summary');
    dl.innerHTML = '';
    const add = (k, v) => {
      const dt = document.createElement('dt'); dt.textContent = k;
      const dd = document.createElement('dd'); dd.textContent = v;
      dl.append(dt, dd);
    };
    add(S.firstname, $('f-firstname').value.trim());
    add(S.lastname, $('f-lastname').value.trim());
    add(S.age, $('f-age').value);
    add(S.gender, draft.gender === 'female' ? S.female : S.male);
  }

  function submit() {
    post('create', {
      firstname: $('f-firstname').value.trim(),
      lastname: $('f-lastname').value.trim(),
      age: parseInt($('f-age').value, 10),
      gender: draft.gender,
      description: $('f-description').value.trim(),
      scale: draft.scale,
      parts: draft.parts,
    });
  }

  function applyStrings() {
    $('t-title').textContent = S.title;
    $('btn-new').textContent = S.create;
    $('l-firstname').textContent = S.firstname;
    $('l-lastname').textContent = S.lastname;
    $('l-age').textContent = S.age;
    $('l-gender').textContent = S.gender;
    $('l-description').textContent = S.description;
    $('l-height').textContent = S.height;
    $('g-male').textContent = S.male;
    $('g-female').textContent = S.female;
    const labels = [S.stepIdentity, S.stepLook, S.stepConfirm];
    document.querySelectorAll('#steps li').forEach((el, i) => { el.textContent = labels[i]; });
  }

  // ---------------- Ereignisse ----------------
  $('btn-new').onclick = () => { resetDraft(); show('create'); post('previewGender', { gender: 'male', scale: heightCfg.default }); };

  $('g-male').onclick = () => setGender('male');
  $('g-female').onclick = () => setGender('female');
  function setGender(g) {
    draft.gender = g;
    draft.parts = {};
    $('g-male').classList.toggle('on', g === 'male');
    $('g-female').classList.toggle('on', g === 'female');
    post('previewGender', { gender: g, scale: draft.scale });
  }

  $('f-height').oninput = (e) => {
    draft.scale = parseFloat(e.target.value);
    post('previewAppearance', { gender: draft.gender, scale: draft.scale, parts: draft.parts });
  };

  $('btn-back').onclick = () => {
    if (step === 1) { show('select'); post('previewGender', { gender: 'male', scale: 1.0 }); return; }
    goStep(step - 1);
  };
  $('btn-next').onclick = () => {
    if (step === 1 && !validateIdentity()) return;
    if (step === 3) return submit();
    goStep(step + 1);
  };

  window.addEventListener('message', (event) => {
    const d = event.data || {};
    switch (d.action) {
      case 'open':
        S = d.strings || {};
        chars = d.characters || [];
        allowDelete = d.allowDelete !== false;
        maxChars = d.maxCharacters || 5;
        limits = { minAge: d.minAge || 18, maxAge: d.maxAge || 90 };
        if (d.height) heightCfg = d.height;
        applyStrings();
        renderList();
        show('select');
        $('app').classList.remove('hidden');
        break;
      case 'characters':
        chars = d.characters || [];
        renderList();
        break;
      case 'error':
        setError(d.message);
        break;
      case 'close':
        $('app').classList.add('hidden');
        break;
    }
  });
})();
