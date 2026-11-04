BEGIN;
UPDATE lifecycle_vagas SET requisitos = '{"obrigatorios": ["JavaScript/TypeScript", "HTML/CSS", "Git", "Node.js", "SQL"], "preferenciais": ["React", "Vue", "Docker", "Inglês"]}'::jsonb WHERE reference='VG-2026-001';
UPDATE lifecycle_vagas SET requisitos = '{"obrigatorios": ["Escuta ativa", "Prospeção comercial", "CRM"], "preferenciais": ["Carta de condução", "Inglês", "PHC"]}'::jsonb WHERE reference='VG-2026-002';
UPDATE lifecycle_vagas SET requisitos = '{"obrigatorios": ["Organização", "Excel", "Português fluente"], "preferenciais": ["Conhecimentos de Qualidade/ISO", "Inglês"]}'::jsonb WHERE reference='VG-2026-003';
UPDATE lifecycle_vagas SET requisitos = '{"obrigatorios": ["Excel", "Processamento de faturas", "Contabilidade básica"], "preferenciais": ["PHC", "Inglês"]}'::jsonb WHERE reference='VG-2026-004';
UPDATE lifecycle_vagas SET requisitos = '{"obrigatorios": ["Windows Server", "Redes (TCP/IP)", "Virtualização"], "preferenciais": ["Linux", "Backups", "Inglês"]}'::jsonb WHERE reference='VG-2026-005';
COMMIT;