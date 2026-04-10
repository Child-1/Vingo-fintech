import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatNaira } from '../lib/utils';
import { Gift, Plus, Pencil, ToggleLeft, ToggleRight } from 'lucide-react';

export default function GiftsPage() {
  const qc = useQueryClient();
  const [activeCategory, setActiveCategory] = useState<number | null>(null);
  const [showCatForm, setShowCatForm] = useState(false);
  const [showItemForm, setShowItemForm] = useState(false);
  const [editingItem, setEditingItem] = useState<any | null>(null);
  const [catForm, setCatForm] = useState({ name: '', slug: '' });
  const [itemForm, setItemForm] = useState({ name: '', emoji: '', valueNaira: '', categoryId: '' });

  /* ── Queries ── */
  const { data: categories } = useQuery({
    queryKey: ['admin-gift-categories'],
    queryFn: () => api.get('/api/admin/gifts/categories').then(r => r.data),
  });

  const { data: items } = useQuery({
    queryKey: ['admin-gift-items', activeCategory],
    queryFn: () => api.get('/api/admin/gifts/items', {
      params: activeCategory ? { categoryId: activeCategory } : {},
    }).then(r => r.data),
  });

  /* ── Mutations ── */
  const createCat = useMutation({
    mutationFn: (payload: typeof catForm) => api.post('/api/admin/gifts/categories', payload),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['admin-gift-categories'] }); setShowCatForm(false); setCatForm({ name: '', slug: '' }); },
  });

  const toggleCat = useMutation({
    mutationFn: ({ id, active }: { id: number; active: boolean }) =>
      api.patch(`/api/admin/gifts/categories/${id}`, { active: !active }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-gift-categories'] }),
  });

  const createItem = useMutation({
    mutationFn: (payload: typeof itemForm) => api.post('/api/admin/gifts/items', {
      ...payload, valueNaira: Number(payload.valueNaira), categoryId: Number(payload.categoryId),
    }),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['admin-gift-items'] });
      setShowItemForm(false);
      setItemForm({ name: '', emoji: '', valueNaira: '', categoryId: '' });
    },
  });

  const updateItem = useMutation({
    mutationFn: ({ id, ...payload }: any) => api.put(`/api/admin/gifts/items/${id}`, {
      ...payload, valueNaira: Number(payload.valueNaira),
    }),
    onSuccess: () => { qc.invalidateQueries({ queryKey: ['admin-gift-items'] }); setEditingItem(null); },
  });

  const toggleItem = useMutation({
    mutationFn: ({ id, active }: { id: number; active: boolean }) =>
      api.patch(`/api/admin/gifts/items/${id}`, { active: !active }),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['admin-gift-items'] }),
  });

  const cats = Array.isArray(categories) ? categories : (categories?.categories ?? []);
  const giftItems = Array.isArray(items) ? items : (items?.items ?? []);

  return (
    <div className="p-6 space-y-5">
      <div>
        <h1 className="text-xl font-semibold text-white">Gift Catalog</h1>
        <p className="text-myraba-hint text-sm">Manage gift categories and items</p>
      </div>

      {/* Categories */}
      <div className="card space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="text-white font-medium text-sm">Categories</h2>
          <button className="btn-ghost flex items-center gap-1.5 text-xs" onClick={() => setShowCatForm(v => !v)}>
            <Plus size={13} /> Add Category
          </button>
        </div>

        {showCatForm && (
          <div className="flex gap-3 items-end border-t border-surface-border pt-3">
            <div className="flex-1">
              <label className="text-myraba-second text-xs block mb-1">Name</label>
              <input className="input" placeholder="Birthday" value={catForm.name}
                onChange={e => setCatForm(f => ({ ...f, name: e.target.value }))} />
            </div>
            <div className="flex-1">
              <label className="text-myraba-second text-xs block mb-1">Slug</label>
              <input className="input" placeholder="birthday" value={catForm.slug}
                onChange={e => setCatForm(f => ({ ...f, slug: e.target.value }))} />
            </div>
            <button className="btn-primary text-sm" disabled={!catForm.name || !catForm.slug || createCat.isPending}
              onClick={() => createCat.mutate(catForm)}>
              {createCat.isPending ? 'Saving…' : 'Save'}
            </button>
            <button className="btn-ghost text-sm" onClick={() => setShowCatForm(false)}>Cancel</button>
          </div>
        )}

        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => setActiveCategory(null)}
            className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-colors ${
              activeCategory === null ? 'bg-brand text-white border-brand' : 'border-surface-border text-myraba-second hover:text-white'
            }`}>
            All Items
          </button>
          {cats.map((c: any) => (
            <div key={c.id} className="flex items-center gap-1">
              <button
                onClick={() => setActiveCategory(c.id)}
                className={`px-3 py-1.5 rounded-full text-xs font-medium border transition-colors ${
                  activeCategory === c.id ? 'bg-brand text-white border-brand' : 'border-surface-border text-myraba-second hover:text-white'
                }`}>
                {c.name} {!c.active && <span className="text-myraba-error">(off)</span>}
              </button>
              <button onClick={() => toggleCat.mutate({ id: c.id, active: c.active })}
                className="text-myraba-hint hover:text-myraba-second">
                {c.active ? <ToggleRight size={14} className="text-myraba-success" /> : <ToggleLeft size={14} />}
              </button>
            </div>
          ))}
        </div>
      </div>

      {/* Items */}
      <div className="space-y-3">
        <div className="flex items-center justify-between">
          <h2 className="text-white font-medium text-sm">
            Gift Items {activeCategory && <span className="text-myraba-hint">— {cats.find((c: any) => c.id === activeCategory)?.name}</span>}
          </h2>
          <button className="btn-ghost flex items-center gap-1.5 text-xs" onClick={() => { setShowItemForm(v => !v); setEditingItem(null); }}>
            <Plus size={13} /> Add Item
          </button>
        </div>

        {showItemForm && !editingItem && (
          <div className="card space-y-3">
            <h3 className="text-white text-sm font-medium">New Gift Item</h3>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-myraba-second text-xs block mb-1">Name</label>
                <input className="input" placeholder="Birthday Cake" value={itemForm.name}
                  onChange={e => setItemForm(f => ({ ...f, name: e.target.value }))} />
              </div>
              <div>
                <label className="text-myraba-second text-xs block mb-1">Emoji</label>
                <input className="input" placeholder="🎂" value={itemForm.emoji}
                  onChange={e => setItemForm(f => ({ ...f, emoji: e.target.value }))} />
              </div>
              <div>
                <label className="text-myraba-second text-xs block mb-1">Value (₦)</label>
                <input className="input" type="number" placeholder="2000" value={itemForm.valueNaira}
                  onChange={e => setItemForm(f => ({ ...f, valueNaira: e.target.value }))} />
              </div>
              <div>
                <label className="text-myraba-second text-xs block mb-1">Category</label>
                <select className="input" value={itemForm.categoryId}
                  onChange={e => setItemForm(f => ({ ...f, categoryId: e.target.value }))}>
                  <option value="">Select category</option>
                  {cats.map((c: any) => <option key={c.id} value={c.id}>{c.name}</option>)}
                </select>
              </div>
            </div>
            <div className="flex gap-3">
              <button className="btn-ghost" onClick={() => setShowItemForm(false)}>Cancel</button>
              <button className="btn-primary"
                disabled={!itemForm.name || !itemForm.valueNaira || !itemForm.categoryId || createItem.isPending}
                onClick={() => createItem.mutate(itemForm)}>
                {createItem.isPending ? 'Saving…' : 'Create Item'}
              </button>
            </div>
          </div>
        )}

        {editingItem && (
          <div className="card space-y-3">
            <h3 className="text-white text-sm font-medium">Edit — {editingItem.name}</h3>
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-myraba-second text-xs block mb-1">Name</label>
                <input className="input" value={editingItem.name}
                  onChange={e => setEditingItem((i: any) => ({ ...i, name: e.target.value }))} />
              </div>
              <div>
                <label className="text-myraba-second text-xs block mb-1">Emoji</label>
                <input className="input" value={editingItem.emoji}
                  onChange={e => setEditingItem((i: any) => ({ ...i, emoji: e.target.value }))} />
              </div>
              <div>
                <label className="text-myraba-second text-xs block mb-1">Value (₦)</label>
                <input className="input" type="number" value={editingItem.valueNaira}
                  onChange={e => setEditingItem((i: any) => ({ ...i, valueNaira: e.target.value }))} />
              </div>
            </div>
            <div className="flex gap-3">
              <button className="btn-ghost" onClick={() => setEditingItem(null)}>Cancel</button>
              <button className="btn-primary" disabled={updateItem.isPending}
                onClick={() => updateItem.mutate(editingItem)}>
                {updateItem.isPending ? 'Saving…' : 'Save Changes'}
              </button>
            </div>
          </div>
        )}

        {giftItems.length === 0 && !showItemForm && !editingItem && (
          <div className="card flex flex-col items-center py-12 text-center">
            <Gift size={40} className="text-myraba-hint mb-3" />
            <p className="text-myraba-second">No gift items{activeCategory ? ' in this category' : ''} yet.</p>
          </div>
        )}

        <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          {giftItems.map((item: any) => (
            <div key={item.id} className={`card flex items-center justify-between gap-3 ${!item.active ? 'opacity-50' : ''}`}>
              <div className="flex items-center gap-3">
                <span className="text-2xl">{item.emoji}</span>
                <div>
                  <p className="text-white text-sm font-medium">{item.name}</p>
                  <p className="text-myraba-success text-xs font-semibold">{formatNaira(item.valueNaira)}</p>
                  {item.categoryName && <p className="text-myraba-hint text-xs">{item.categoryName}</p>}
                </div>
              </div>
              <div className="flex items-center gap-1 flex-shrink-0">
                <button onClick={() => { setEditingItem(item); setShowItemForm(false); }}
                  className="btn-ghost p-1.5 text-myraba-second hover:text-white">
                  <Pencil size={13} />
                </button>
                <button onClick={() => toggleItem.mutate({ id: item.id, active: item.active })}
                  className="btn-ghost p-1.5">
                  {item.active
                    ? <ToggleRight size={16} className="text-myraba-success" />
                    : <ToggleLeft size={16} className="text-myraba-hint" />}
                </button>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
