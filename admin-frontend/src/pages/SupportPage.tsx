import { useState, useEffect, useRef } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../lib/api';
import { formatDate } from '../lib/utils';
import { MessageCircle, Send, User } from 'lucide-react';

interface Conversation {
  userId: number;
  handle: string;
  fullName: string;
  lastMessage: string | null;
  lastAt: string | null;
  unreadCount: number;
}

interface Message {
  id: number;
  sender: 'USER' | 'AGENT';
  content: string;
  isRead: boolean;
  createdAt: string;
}

export default function SupportPage() {
  const qc = useQueryClient();
  const [selected, setSelected] = useState<Conversation | null>(null);
  const [reply, setReply] = useState('');
  const bottomRef = useRef<HTMLDivElement>(null);

  const { data: convoData } = useQuery({
    queryKey: ['support-conversations'],
    queryFn: () => api.get('/api/admin/support/conversations').then(r => r.data),
    refetchInterval: 10_000,
  });

  const { data: msgData } = useQuery({
    queryKey: ['support-messages', selected?.userId],
    queryFn: () => api.get(`/api/admin/support/conversations/${selected!.userId}`).then(r => r.data),
    enabled: !!selected,
    refetchInterval: 8_000,
  });

  const send = useMutation({
    mutationFn: () => api.post(`/api/admin/support/conversations/${selected!.userId}/reply`, { content: reply }),
    onSuccess: () => {
      setReply('');
      qc.invalidateQueries({ queryKey: ['support-messages', selected?.userId] });
      qc.invalidateQueries({ queryKey: ['support-conversations'] });
    },
  });

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [msgData]);

  const conversations: Conversation[] = convoData?.conversations ?? [];
  const messages: Message[] = msgData?.messages ?? [];

  return (
    <div className="flex h-[calc(100vh-64px)] overflow-hidden">
      {/* ── Sidebar ─────────────────────────────────────────── */}
      <div className="w-80 border-r border-gray-200 dark:border-gray-700 flex flex-col">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700">
          <h2 className="text-lg font-bold text-gray-900 dark:text-white flex items-center gap-2">
            <MessageCircle size={20} className="text-green-500" />
            Support Inbox
          </h2>
          <p className="text-xs text-gray-500 mt-0.5">{conversations.length} conversations</p>
        </div>
        <div className="flex-1 overflow-y-auto">
          {conversations.length === 0 && (
            <p className="text-center text-gray-400 text-sm mt-12">No messages yet</p>
          )}
          {conversations.map(c => (
            <button
              key={c.userId}
              onClick={() => setSelected(c)}
              className={`w-full text-left px-4 py-3 border-b border-gray-100 dark:border-gray-800 hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors ${
                selected?.userId === c.userId ? 'bg-green-50 dark:bg-green-900/20' : ''
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="font-semibold text-sm text-gray-900 dark:text-white truncate">{c.fullName}</span>
                {c.unreadCount > 0 && (
                  <span className="ml-2 min-w-[20px] h-5 rounded-full bg-green-500 text-white text-xs flex items-center justify-center px-1">
                    {c.unreadCount}
                  </span>
                )}
              </div>
              <p className="text-xs text-gray-400 truncate mt-0.5">m₦ {c.handle}</p>
              {c.lastMessage && (
                <p className="text-xs text-gray-500 truncate mt-1">{c.lastMessage}</p>
              )}
              {c.lastAt && (
                <p className="text-xs text-gray-400 mt-0.5">{formatDate(c.lastAt)}</p>
              )}
            </button>
          ))}
        </div>
      </div>

      {/* ── Chat panel ──────────────────────────────────────── */}
      {!selected ? (
        <div className="flex-1 flex flex-col items-center justify-center text-gray-400">
          <MessageCircle size={48} className="mb-4 opacity-30" />
          <p className="text-sm">Select a conversation to view messages</p>
        </div>
      ) : (
        <div className="flex-1 flex flex-col">
          {/* Header */}
          <div className="px-6 py-4 border-b border-gray-200 dark:border-gray-700 flex items-center gap-3">
            <div className="w-9 h-9 rounded-full bg-gray-100 dark:bg-gray-700 flex items-center justify-center">
              <User size={18} className="text-gray-500" />
            </div>
            <div>
              <p className="font-semibold text-gray-900 dark:text-white text-sm">{selected.fullName}</p>
              <p className="text-xs text-gray-400">m₦ {selected.handle}</p>
            </div>
          </div>

          {/* Messages */}
          <div className="flex-1 overflow-y-auto px-6 py-4 space-y-3">
            {messages.map(msg => (
              <div
                key={msg.id}
                className={`flex ${msg.sender === 'AGENT' ? 'justify-end' : 'justify-start'}`}
              >
                <div
                  className={`max-w-sm px-4 py-2.5 rounded-2xl text-sm leading-relaxed ${
                    msg.sender === 'AGENT'
                      ? 'bg-green-500 text-white rounded-br-sm'
                      : 'bg-gray-100 dark:bg-gray-700 text-gray-900 dark:text-white rounded-bl-sm'
                  }`}
                >
                  {msg.content}
                  <p className={`text-xs mt-1 ${msg.sender === 'AGENT' ? 'text-green-100' : 'text-gray-400'}`}>
                    {formatDate(msg.createdAt)}
                  </p>
                </div>
              </div>
            ))}
            <div ref={bottomRef} />
          </div>

          {/* Reply bar */}
          <div className="px-4 py-3 border-t border-gray-200 dark:border-gray-700 flex gap-2">
            <input
              className="flex-1 input text-sm"
              placeholder="Type a reply…"
              value={reply}
              onChange={e => setReply(e.target.value)}
              onKeyDown={e => {
                if (e.key === 'Enter' && !e.shiftKey && reply.trim()) {
                  e.preventDefault();
                  send.mutate();
                }
              }}
            />
            <button
              onClick={() => reply.trim() && send.mutate()}
              disabled={!reply.trim() || send.isPending}
              className="btn-primary px-4 flex items-center gap-1.5 disabled:opacity-50"
            >
              <Send size={15} />
              Send
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
