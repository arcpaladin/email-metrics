import { useState } from 'react';
import { Dialog, DialogContent } from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { useToast } from '@/hooks/use-toast';
import { AuthManager, MSALService } from '@/lib/auth';
import { apiRequest } from '@/lib/queryClient';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

export function AuthModal({ isOpen, onClose, onSuccess }: AuthModalProps) {
  const [isLoading, setIsLoading] = useState(false);
  const { toast } = useToast();

  const handleMicrosoftSignIn = async () => {
    setIsLoading(true);
    try {
      // Get access token from Microsoft
      const msalResult = await MSALService.signIn();
      
      // Authenticate with our backend
      const response = await apiRequest('POST', '/api/auth/microsoft', {
        accessToken: msalResult.accessToken
      });
      
      const authData = await response.json();
      
      // Store authentication data
      AuthManager.setAuth(authData.token, authData.user);
      
      toast({
        title: "Welcome!",
        description: "Successfully signed in with Microsoft.",
      });
      
      onSuccess();
      onClose();
    } catch (error) {
      console.error('Authentication error:', error);
      toast({
        title: "Authentication Failed",
        description: "Please try again.",
        variant: "destructive",
      });
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <Dialog open={isOpen} onOpenChange={onClose}>
      <DialogContent className="max-w-md">
        <div className="text-center mb-6">
          <div className="w-16 h-16 bg-blue-500 rounded-full flex items-center justify-center mx-auto mb-4">
            <i className="fas fa-envelope text-white text-2xl"></i>
          </div>
          <h2 className="text-2xl font-semibold text-gray-900 mb-2">
            Email Analytics Dashboard
          </h2>
          <p className="text-gray-600">
            Sign in with your Microsoft account to continue
          </p>
        </div>
        
        <Button 
          onClick={handleMicrosoftSignIn}
          disabled={isLoading}
          className="w-full bg-blue-500 hover:bg-blue-600 text-white font-medium py-3 px-4 rounded-lg transition-all flex items-center justify-center mb-4"
        >
          {isLoading ? (
            <>
              <div className="animate-spin rounded-full h-4 w-4 border-b-2 border-white mr-2" />
              Signing in...
            </>
          ) : (
            <>
              <i className="fab fa-microsoft mr-2"></i>
              Sign in with Microsoft
            </>
          )}
        </Button>
        
        <div className="text-center">
          <p className="text-sm text-gray-500">
            Secure authentication via Microsoft Entra ID
          </p>
        </div>
      </DialogContent>
    </Dialog>
  );
}
