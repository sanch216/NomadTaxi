import { ReactNode } from 'react';
import './SlideOutPanel.css';

interface SlideOutPanelProps {
  isOpen: boolean;
  onClose: () => void;
  title: string;
  children: ReactNode;
}

export default function SlideOutPanel({ isOpen, onClose, title, children }: SlideOutPanelProps) {
  if (!isOpen) return null;

  return (
    <>
      <div className="slide-out-overlay" onClick={onClose} />
      <div className="slide-out-panel">
        <div className="slide-out-header">
          <h2>{title}</h2>
          <button className="close-btn" onClick={onClose}>&times;</button>
        </div>
        <div className="slide-out-content">
          {children}
        </div>
      </div>
    </>
  );
}
