;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")
(setq user-full-name "Diviyan Kalainathan"
      user-mail-address "diviyan@fentech.ai")


;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-beach-dark)
(setq doom-font (font-spec :family "JetBrains Mono" :size 14 :weight 'medium)
      doom-variable-pitch-font (font-spec :family "Nunito" :size 14)
      )
(setq shell-file-name (executable-find "bash"))
;;(setq-default line-spacing 0)
;; doom-variable-pitch-font (font-spec :family "Monaspace Neon Var" :size 15))
;; (setq doom-font (font-spec :family "Source Code Pro" :size 14))
;; (setq doom-font (font-spec :family "Iosevka Nerd Font" :size 14))
;; (setq doom-font (font-spec :family "Inconsolata Nerd Font Mono" :size 14))
(setq doom-symbol-font (font-spec :family "Font Awesome 6 Free" :size 14))
;; This determines the style of line numbers in effect. If set to `nil',

;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

(setq projectile-project-search-path '(("~/fentech" . 1)("~/fentech/algorithm" . 3) ("~/fentech/tools" . 2)("~/fentech/research" . 2) ("~/fentech/report" . 2) ("~/fentech/pct" . 2)  ("~/fentech/tools" . 2) ("~/fentech/dsales/" . 2) ("~/fentech/study" . 1) ("~/research" . 2)))
(setq evil-scroll-count 1)
(setq avy-keys '(?a ?r ?s ?t ?m ?n ?e ?i ?o))
;;        (use-package! lsp-bridge
;;  :config
;;  (setq lsp-bridge-enable-log nil)
;;  (global-lsp-bridge-mode))
;; (key-chord-define evil-insert-state-map "jd" 'evil-delete-backward-word)
;; (key-chord-define evil-insert-state-map "jh" 'evil-backward-WORD-begin)
;; (key-chord-define evil-insert-state-map "jl" 'evil-forward-WORD-end)
(map! :nv "C-c C-o" #'better-jumper-set-jump)
(map! :nv "C-c [" #'better-jumper-clear-jumps)
(map! :nv "C-d" #'(lambda() (interactive) (evil-scroll-down 10)))
(map! :nv "C-u" #'(lambda() (interactive) (evil-scroll-up 10)))
(map! :nvi "M-T" #'evil-forward-word-end)
(map! :nvi "M-t" #'evil-forward-WORD-end)
(map! :nvi "M-N" #'evil-backward-word-begin)
(map! :nvi "M-n" #'evil-backward-WORD-begin)
(map! :i "C-n" #'evil-beginning-of-visual-line)
(map! :i "C-o" #'evil-end-of-visual-line)
(map! :i "RET" #'evil-ret-and-indent)
(map! "C-c C-t" #'+workspace/delete)
(map! :nv "M-o" #'+evil/insert-newline-above)
(map! :nv "M-O" #'+evil/insert-newline-below)
(map! :nv "M-p" #'evil-paste-after)
(map! :i "M-p" #'evil-paste-before-cursor-after)
(map! :nvi "M-P" #'evil-paste-before)
(map! :ni "M-[" #'evil-prev-buffer)
(map! :ni "M-]" #'evil-next-buffer)
(map! :ni "M-<left>" #'evil-window-left)
(map! :ni "M-<right>" #'evil-window-right)
(map! :nv "g s l" #'evil-avy-goto-line)
(map! :nv "g s o" #'evil-avy-goto-word-1)
(map! :i "C-g" #'evil-execute-in-normal-state)
(setq-hook! 'python-mode-hook +format-with-lsp 'ruff-format-on-save-mode)
(after! evil-escape
  (setq evil-escape-key-sequence ",."))

(after! evil-escape
  (map! :i "C-<return>" #'evil-escape))

(setq flycheck-python-pyright-executable "/home/diviyan/.pyenv/shims/pyright")
(setq lsp-semgrep-scan-max-memory 500)
(setq lsp-semgrep-scan-max-target-bytes 30)
;; (add-hook 'python-mode-hook
;;           (defun set-checker-hook-100 ()
;;             (flycheck-mode 1)
;;             (flycheck-select-checker 'python-pyright)))
;; (define-key doom-leader-file-map (kbd "F") #'affe-find)
(defun run-latex ()
  (interactive)
  (let ((process (TeX-active-process))) (if process (delete-process process)))
  (let ((TeX-save-query nil)) (TeX-save-document ""))
  (TeX-command-menu "LaTeX"))
(add-hook 'LaTeX-mode-hook (lambda () (local-set-key (kbd "C-x C-s") #'run-latex)));;
(setq vimish-fold-marks '("\"\"\"" . "\"\"\""))
(add-hook 'python-mode-hook
          (lambda ()
            (vimish-fold-mode)
            ;; (vimish-fold-delete-all)
            (vimish-fold-refold-all)
            ));;

(defun efs/org-mode-setup ()
  (org-indent-mode)
  (variable-pitch-mode 1)
  (visual-line-mode 1))

(defun efs/org-font-setup ()
  ;; Replace list hyphen with dot
  (font-lock-add-keywords 'org-mode
                          '(("^ *\\([-]\\) "
                             (0 (prog1 () (compose-region (match-beginning 1) (match-end 1) "•"))))))

  ;; Set faces for heading levels
  (dolist (face '((org-level-1 . 1.2)
                  (org-level-2 . 1.1)
                  (org-level-3 . 1.05)
                  (org-level-4 . 1.0)
                  (org-level-5 . 1.1)
                  (org-level-6 . 1.1)
                  (org-level-7 . 1.1)
                  (org-level-8 . 1.1)))
    (set-face-attribute (car face) nil :font "Nunito" :weight 'regular :height (cdr face)))

  ;; Ensure that anything that should be fixed-pitch in Org files appears that way
  (set-face-attribute 'org-block nil :foreground nil :inherit 'fixed-pitch)
  (set-face-attribute 'org-code nil   :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-table nil   :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-verbatim nil :inherit '(shadow fixed-pitch))
  (set-face-attribute 'org-special-keyword nil :inherit '(font-lock-comment-face fixed-pitch))
  (set-face-attribute 'org-meta-line nil :inherit '(font-lock-comment-face fixed-pitch))
  (set-face-attribute 'org-checkbox nil :inherit 'fixed-pitch))

(setq lsp-inlay-hint-enable t)
(setq lsp-rust-analyzer-display-lifetime-elision-hints-enable "skip_trivial")
(setq lsp-rust-analyzer-display-chaining-hints t)
(setq lsp-rust-analyzer-display-lifetime-elision-hints-use-parameter-names t)
(setq lsp-rust-analyzer-display-closure-return-type-hints t)
(setq lsp-rust-analyzer-display-parameter-hints t)
(setq lsp-rust-analyzer-display-reborrow-hints t)

(add-hook 'org-mode
          (lambda ()
            (efs/org-mode-setup)
            (org-indent-mode)
            (visual-line-mode 1)
            (variable-pitch-mode 1)
            )
          )

(after! org
  :config
  ;; (setq org-ellipsis " ▾")
  (efs/org-font-setup))



(defun efs/org-mode-visual-fill ()
  (setq visual-fill-column-width 100
        visual-fill-column-center-text t)
  (visual-fill-column-mode 1))

(use-package visual-fill-column
  :hook (org-mode . efs/org-mode-visual-fill))


(use-package! typst-ts-mode
  :defer t
  :config
  (add-to-list 'auto-mode-alist '("\\.typ" . typst-ts-mode))
  :custom
  (typst-ts-mode-watch-options "--open")
  )
;;
;; (after! elpy
;;   (set-company-backend! 'elpy-mode
;;     '(elpy-company-backend :with company-files company-yasnippet)));;
;; colemak
;; (after! evil
;;   (map! :nv "l" 'evil-insert
;;         :nv "L" 'evil-insert-line
;;         :nv "n" 'evil-backward-char
;;         :nv "o" 'evil-forward-char
;;         :nv "e" 'evil-next-line
;;         :nv "i" 'evil-previous-line
;;         :nv "h" 'evil-forward-word-end
;;         :n  "N" 'evil-join
;;         :nv "j" 'evil-ex-search-next
;;         :nv "j" 'evil-snipe-repeat))
;;
;; (after! magit
;;   (map! :map magit-mode-map
;;         :n "e" 'magit-next-line
;;         :n "i" 'magit-previous-line))
;;
;; (map! :map org-agenda-mode-map
;;       :m "e" 'org-agenda-next-line
;;       :m "i" 'org-agenda-previous-line
;;       )
;; Env vars
(setq projectile-project-root-functions '(projectile-root-local
                                          projectile-root-top-down
                                          projectile-root-top-down-recurring
                                          projectile-root-bottom-up))

;;
;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `after!' block, otherwise Doom's defaults may override your settings. E.g.
;;
;;
;;   (after! PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look up their documentation).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.

(setq lsp-tex-server 'digestif)
