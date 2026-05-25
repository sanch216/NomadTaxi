import { createContext, useContext, useState, useCallback, ReactNode } from 'react';
import Modal from './Modal';

interface ConfirmOptions {
  title: string;
  message: string;
  confirmText?: string;
  cancelText?: string;
  variant?: 'danger' | 'warning' | 'success' | 'primary';
  /** If true, shows a textarea input for the user to type a reason/note */
  inputLabel?: string;
  inputPlaceholder?: string;
  inputRequired?: boolean;
}

interface ConfirmResult {
  confirmed: boolean;
  inputValue?: string;
}

interface ConfirmContextType {
  confirm: (options: ConfirmOptions) => Promise<ConfirmResult>;
}

const ConfirmContext = createContext<ConfirmContextType | null>(null);

export function ConfirmProvider({ children }: { children: ReactNode }) {
  const [isOpen, setIsOpen] = useState(false);
  const [options, setOptions] = useState<ConfirmOptions | null>(null);
  const [inputValue, setInputValue] = useState('');
  const [resolveRef, setResolveRef] = useState<((result: ConfirmResult) => void) | null>(null);

  const confirm = useCallback((opts: ConfirmOptions): Promise<ConfirmResult> => {
    return new Promise((resolve) => {
      setOptions(opts);
      setInputValue('');
      setIsOpen(true);
      setResolveRef(() => resolve);
    });
  }, []);

  const handleConfirm = () => {
    setIsOpen(false);
    resolveRef?.({ confirmed: true, inputValue: inputValue || undefined });
  };

  const handleCancel = () => {
    setIsOpen(false);
    resolveRef?.({ confirmed: false });
  };

  const variantClass = options?.variant ? `btn-${options.variant}` : 'btn-danger';

  return (
    <ConfirmContext.Provider value={{ confirm }}>
      {children}
      <Modal isOpen={isOpen} onClose={handleCancel} title={options?.title || 'Confirm'}>
        <div style={{ marginBottom: '1rem', color: 'var(--text-muted)', lineHeight: 1.6 }}>
          {options?.message}
        </div>
        {options?.inputLabel && (
          <div className="form-group">
            <label>{options.inputLabel}</label>
            <textarea
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              placeholder={options.inputPlaceholder || ''}
              required={options.inputRequired}
              rows={3}
            />
          </div>
        )}
        <div className="modal-actions">
          <button className="btn btn-secondary" onClick={handleCancel}>
            {options?.cancelText || 'Cancel'}
          </button>
          <button
            className={`btn ${variantClass}`}
            onClick={handleConfirm}
            disabled={options?.inputRequired && !inputValue.trim()}
          >
            {options?.confirmText || 'Confirm'}
          </button>
        </div>
      </Modal>
    </ConfirmContext.Provider>
  );
}

export function useConfirm() {
  const context = useContext(ConfirmContext);
  if (!context) {
    throw new Error('useConfirm must be used within a ConfirmProvider');
  }
  return context.confirm;
}
