import { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import { userService, rideService, ticketService } from '../services/api';
import { useDebounce } from '../hooks/useDebounce';
import './GlobalSearch.css';

interface SearchResult {
  id: number;
  type: 'USER' | 'RIDE' | 'TICKET';
  title: string;
  subtitle: string;
  url: string;
}

export default function GlobalSearch() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const [loading, setLoading] = useState(false);
  const [isOpen, setIsOpen] = useState(false);
  const debouncedQuery = useDebounce(query, 300);
  const searchRef = useRef<HTMLDivElement>(null);
  const navigate = useNavigate();

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        document.getElementById('global-search-input')?.focus();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, []);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (searchRef.current && !searchRef.current.contains(event.target as Node)) {
        setIsOpen(false);
      }
    };
    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  useEffect(() => {
    if (!debouncedQuery.trim()) {
      setResults([]);
      setIsOpen(false);
      return;
    }

    const performSearch = async () => {
      setLoading(true);
      setIsOpen(true);
      try {
        // Run searches in parallel
        // For a real implementation, you might want a dedicated global search endpoint
        // Here we simulate it by querying multiple endpoints
        const [usersRes, ridesRes, ticketsRes] = await Promise.allSettled([
          userService.getUsers({ size: 5 }), // You'd ideally pass the query to the backend
          rideService.getRides({ size: 5 }),
          ticketService.getTickets()
        ]);

        const combinedResults: SearchResult[] = [];
        const q = debouncedQuery.toLowerCase();

        // Process Users (assuming client-side filter for now since backend lacks search param)
        if (usersRes.status === 'fulfilled') {
          const users = usersRes.value.data.content || usersRes.value.data;
          if (Array.isArray(users)) {
            users.filter(u => u.phone.includes(q) || (u.fullName && u.fullName.toLowerCase().includes(q)))
              .slice(0, 3)
              .forEach(u => combinedResults.push({
                id: u.id,
                type: 'USER',
                title: u.fullName || u.phone,
                subtitle: `Phone: ${u.phone} • Role: ${u.role}`,
                url: '/users'
              }));
          }
        }

        // Process Rides
        if (ridesRes.status === 'fulfilled') {
          const rides = ridesRes.value.data.content || ridesRes.value.data;
          if (Array.isArray(rides)) {
            rides.filter(r => r.id.toString().includes(q) || (r.clientName && r.clientName.toLowerCase().includes(q)))
              .slice(0, 3)
              .forEach(r => combinedResults.push({
                id: r.id,
                type: 'RIDE',
                title: `Ride #${r.id}`,
                subtitle: `Client: ${r.clientName} • Status: ${r.status}`,
                url: '/rides'
              }));
          }
        }

        // Process Tickets
        if (ticketsRes.status === 'fulfilled') {
          const tickets = ticketsRes.value.data;
          if (Array.isArray(tickets)) {
            tickets.filter(t => t.id.toString().includes(q) || (t.subject && t.subject.toLowerCase().includes(q)))
              .slice(0, 3)
              .forEach(t => combinedResults.push({
                id: t.id,
                type: 'TICKET',
                title: `Ticket #${t.id}: ${t.subject}`,
                subtitle: `User: ${t.userName} • Status: ${t.status}`,
                url: '/tickets'
              }));
          }
        }

        setResults(combinedResults);
      } catch (error) {
        console.error("Search failed", error);
      } finally {
        setLoading(false);
      }
    };

    performSearch();
  }, [debouncedQuery]);

  const handleResultClick = (url: string) => {
    navigate(url);
    setIsOpen(false);
    setQuery('');
  };

  return (
    <div className="global-search-container" ref={searchRef}>
      <div className="global-search">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="11" cy="11" r="8"></circle>
          <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
        </svg>
        <input 
          id="global-search-input"
          type="text" 
          placeholder="Global search... (Press Ctrl+K)" 
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => { if (query.trim()) setIsOpen(true); }}
        />
        {loading && <div className="search-spinner"></div>}
      </div>

      {isOpen && (
        <div className="search-dropdown glass-panel">
          {results.length === 0 && !loading ? (
            <div className="search-empty">No results found for "{query}"</div>
          ) : (
            results.map((result, idx) => (
              <div 
                key={`${result.type}-${result.id}-${idx}`} 
                className="search-result-item"
                onClick={() => handleResultClick(result.url)}
              >
                <div className="search-result-icon">
                  {result.type === 'USER' && <span>👤</span>}
                  {result.type === 'RIDE' && <span>🚗</span>}
                  {result.type === 'TICKET' && <span>🎫</span>}
                </div>
                <div className="search-result-info">
                  <div className="search-result-title">{result.title}</div>
                  <div className="search-result-subtitle">{result.subtitle}</div>
                </div>
              </div>
            ))
          )}
        </div>
      )}
    </div>
  );
}
