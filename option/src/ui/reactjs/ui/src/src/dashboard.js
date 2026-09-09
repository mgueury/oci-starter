import React, { useCallback, useEffect, useState } from "react";
import {
    Box, Button, Card, CardContent, Chip, CircularProgress, Container,
    Divider, Link, Paper, Stack, Table, TableBody, TableCell,
    TableContainer, TableHead, TableRow, Typography,
} from '@mui/material';
import CloudOutlinedIcon from '@mui/icons-material/CloudOutlined';
import ErrorOutlineIcon from '@mui/icons-material/ErrorOutlined';
import RefreshIcon from '@mui/icons-material/Refresh';
import axios from "axios";

const stackLabels = ['Deployment', 'Database', 'Language', 'Framework'];

function getStackDetails(info) {
    const values = String(info || '').split(/\s+-\s+/).map((value) => value.trim()).filter(Boolean);
    if (values.length >= 4) return values.slice(0, 4).map((value, index) => ({ label: stackLabels[index], value }));
    return info ? [{ label: 'Stack', value: info }] : [];
}

export default function Dashboard() {
    const [data, setData] = useState([]);
    const [info, setInfo] = useState('');
    const [departmentState, setDepartmentState] = useState('loading');
    const [infoState, setInfoState] = useState('loading');

    const refreshData = useCallback(async () => {
        setDepartmentState('loading');
        setInfoState('loading');

        const [departmentsResult, infoResult] = await Promise.allSettled([
            axios.get('app/dept'),
            axios.get('app/info'),
        ]);

        if (departmentsResult.status === 'fulfilled') {
            const departments = Array.isArray(departmentsResult.value.data) ? departmentsResult.value.data : [];
            setData(departments);
            setDepartmentState(departments.length ? 'ready' : 'empty');
        } else {
            console.log(departmentsResult.reason);
            setDepartmentState('error');
        }

        if (infoResult.status === 'fulfilled') {
            setInfo(String(infoResult.value.data || ''));
            setInfoState('ready');
        } else {
            console.log(infoResult.reason);
            setInfoState('error');
        }
    }, []);

    useEffect(() => { refreshData(); }, [refreshData]);

    const isRefreshing = departmentState === 'loading' || infoState === 'loading';
    const isAvailable = !isRefreshing && departmentState !== 'error' && infoState !== 'error';
    const details = getStackDetails(info);

    return (
        <Box sx={{ minHeight: '100vh', bgcolor: 'background.default' }}>
            <Box
                sx={{
                    color: '#fff', minHeight: { xs: 290, md: 250 },
                    backgroundColor: '#651b19',
                    backgroundImage: 'linear-gradient(90deg, rgba(63, 10, 11, .76) 0%, rgba(126, 30, 24, .43) 48%, rgba(126, 33, 29, .14) 100%), url(./stack-background.jpg)',
                    backgroundPosition: 'center', backgroundRepeat: 'no-repeat', backgroundSize: 'cover',
                }}
            >
                <Container maxWidth="md" sx={{ pt: 2.5, pb: { xs: 4, md: 5 } }}>
                    <Box sx={{ position: 'relative', minHeight: 26 }}>
                        <Stack direction="row" spacing={0.9} alignItems="center">
                            <CloudOutlinedIcon sx={{ fontSize: 24 }} />
                            <Typography sx={{ fontWeight: 800, letterSpacing: '-0.04em' }}>OCI Starter</Typography>
                        </Stack>
                        <Link href="app/info" target="_blank" rel="noreferrer" underline="hover" color="inherit" sx={{ position: 'absolute', top: 3, right: 0, fontSize: 12, fontWeight: 700, whiteSpace: 'nowrap' }}>API endpoint ↗</Link>
                    </Box>
                    <Box sx={{ mt: { xs: 5, md: 4.5 }, maxWidth: 550 }}>
                        <Typography variant="h3" sx={{ fontSize: { xs: '2.2rem', md: '2.75rem' }, color: '#fff' }}>Your cloud stack is ready.</Typography>
                        <Typography sx={{ mt: 1.25, maxWidth: 500, color: '#fff', fontWeight: 500 }}>{infoState === 'ready' ? info : 'Checking the configuration of your OCI Starter deployment.'}</Typography>
                        <Chip
                            icon={isRefreshing ? <CircularProgress size={14} color="inherit" /> : <CloudOutlinedIcon />}
                            label={isRefreshing ? 'Checking service' : isAvailable ? 'Service available' : 'Service needs attention'}
                            sx={{ mt: 2.25, color: '#fff', fontWeight: 750, bgcolor: isAvailable ? 'rgba(18, 48, 31, .66)' : 'rgba(90, 27, 24, .72)', border: '1px solid rgba(255,255,255,.26)' }}
                        />
                    </Box>
                </Container>
            </Box>

            <Container maxWidth="md" sx={{ py: { xs: 3, md: 3.75 } }}>
                <Button variant="outlined" startIcon={isRefreshing ? <CircularProgress size={16} /> : <RefreshIcon />} onClick={refreshData} disabled={isRefreshing} sx={{ mb: 2, borderColor: '#d3cbc7', color: 'text.primary', bgcolor: '#fff', textTransform: 'none', fontWeight: 750 }}>Refresh data</Button>

                <Card>
                    <CardContent sx={{ p: 0 }}>
                        <Box sx={{ px: 2.4, py: 1.65 }}><Typography variant="overline" sx={{ color: 'text.secondary' }}>Departments</Typography></Box>
                        <Divider />
                        {departmentState === 'error' ? <ErrorState /> : departmentState === 'empty' ? <EmptyState /> : <DepartmentTable data={data} loading={departmentState === 'loading'} />}
                    </CardContent>
                </Card>

                <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ mt: 2 }}>
                    <Card sx={{ flex: 1.05 }}>
                        <CardContent sx={{ p: 2.7 }}>
                            <Typography variant="overline" sx={{ color: 'text.secondary' }}>Service information</Typography>
                            <Typography variant="h6" sx={{ mt: 0.3 }}>{isAvailable ? 'Service available' : 'Service status'}</Typography>
                            {infoState === 'error' ? <Typography color="text.secondary" sx={{ mt: 1 }}>Stack information is temporarily unavailable.</Typography> : <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(2, minmax(0, 1fr))', gap: 1, mt: 1.8 }}>{details.map((detail) => <Box key={detail.label} sx={{ minWidth: 0, p: 1.1, borderRadius: 1.2, bgcolor: '#f3efed' }}><Typography variant="overline" sx={{ display: 'block', color: 'text.secondary', fontSize: '0.58rem', lineHeight: 1.2 }}>{detail.label}</Typography><Typography sx={{ mt: 0.4, fontSize: '0.78rem', lineHeight: 1.25, fontWeight: 800, overflowWrap: 'anywhere' }}>{detail.value}</Typography></Box>)}</Box>}
                            <Link href="app/dept" target="_blank" rel="noreferrer" underline="hover" sx={{ display: 'inline-block', mt: 2.1, fontWeight: 800, color: 'primary.dark' }}>View API response ↗</Link>
                        </CardContent>
                    </Card>
                    <Card sx={{ flex: 1, bgcolor: '#fff4f1', borderColor: '#f1c7bf' }}>
                        <CardContent sx={{ p: 2.7 }}>
                            <Typography variant="overline" sx={{ color: 'text.secondary' }}>Keep building</Typography>
                            <Typography sx={{ mt: 1.1, color: '#5d4641' }}>Use this dashboard as a starting point for building a service around your own data.</Typography>
                            <Link href="https://www.ocistarter.com/help" target="_blank" rel="noreferrer" underline="hover" sx={{ display: 'inline-block', mt: 2.1, fontWeight: 800, color: 'primary.dark' }}>Open tutorial ↗</Link>
                        </CardContent>
                    </Card>
                </Stack>
            </Container>
        </Box>
    );
}

function DepartmentTable({ data, loading }) {
    return <TableContainer sx={{ overflowX: 'auto' }}><Table aria-label="Departments"><TableHead><TableRow><TableCell>Deptno</TableCell><TableCell>Dname</TableCell><TableCell>Loc</TableCell></TableRow></TableHead><TableBody>{loading ? <TableRow><TableCell colSpan={3} sx={{ py: 4, textAlign: 'center' }}><CircularProgress size={23} aria-label="Loading departments" /></TableCell></TableRow> : data.map((row) => <TableRow key={row.deptno} hover><TableCell>{row.deptno}</TableCell><TableCell>{row.dname}</TableCell><TableCell>{row.loc}</TableCell></TableRow>)}</TableBody></Table></TableContainer>;
}

function ErrorState() {
    return <Box sx={{ px: 3, py: 5, textAlign: 'center' }}><ErrorOutlineIcon color="error" sx={{ fontSize: 34, mb: 1 }} /><Typography variant="h6">We could not load departments</Typography><Typography color="text.secondary">Check that the application REST service is available, then refresh the data.</Typography></Box>;
}

function EmptyState() {
    return <Box sx={{ px: 3, py: 5, textAlign: 'center' }}><Typography variant="h6">No departments found</Typography><Typography color="text.secondary">The service responded successfully, but there are no department records to display.</Typography></Box>;
}
