<?php

use Illuminate\Support\Facades\Route;
use App\Http\Controllers\ReportController;

Route::post('/reports', [ReportController::class, 'store']);
