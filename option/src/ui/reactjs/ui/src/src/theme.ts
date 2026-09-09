import { createTheme } from '@mui/material/styles';

const theme = createTheme({
  palette: {
    mode: 'light',
    primary: {
      main: '#c23b2d',
      dark: '#a52d23',
      light: '#f5d7d1',
    },
    secondary: {
      main: '#172b4d',
      dark: '#0d1b2f',
      light: '#e8edf5',
    },
    background: {
      default: '#f7f5f4',
      paper: '#ffffff',
    },
  },
  shape: { borderRadius: 11 },
  typography: {
    fontFamily: 'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    h3: { fontWeight: 800, letterSpacing: '-0.055em', lineHeight: 1.02 },
    h4: { fontWeight: 750, letterSpacing: '-0.035em' },
    h6: { fontWeight: 700, letterSpacing: '-0.02em' },
    overline: { fontWeight: 800, letterSpacing: '0.1em' },
  },
  components: {
    MuiCard: { styleOverrides: { root: { border: '1px solid #ded7d3', boxShadow: '0 2px 6px rgba(68, 43, 36, .05)' } } },
    MuiTableCell: { styleOverrides: { head: { backgroundColor: '#fbfaf9', color: '#625d5a', fontWeight: 800, fontSize: '0.67rem', letterSpacing: '0.1em', textTransform: 'uppercase' } } },
  },
});

export default theme;
