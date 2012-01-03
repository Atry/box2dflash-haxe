/*
* Copyright (c) 2006-2010 Erin Catto http://www.gphysics.com
* Copyright (c) 2012 Yang Bo <pop.atry@gmail.com>. All rights reserved. 
*
* This software is provided 'as-is', without any express or implied
* warranty.  In no event will the authors be held liable for any damages
* arising from the use of this software.
* Permission is granted to anyone to use this software for any purpose,
* including commercial applications, and to alter it and redistribute it
* freely, subject to the following restrictions:
* 1. The origin of this software must not be misrepresented; you must not
* claim that you wrote the original software. If you use this software
* in a product, an acknowledgment in the product documentation would be
* appreciated but is not required.
* 2. Altered source versions must be plainly marked as such, and must not be
* misrepresented as being the original software.
* 3. This notice may not be removed or altered from any source distribution.
*/

package Box2D.Dynamics.Joints {

import Box2D.Common.*;
import Box2D.Common.Math.*;
import Box2D.Dynamics.*;

import Box2D.Common.b2internal;
use namespace b2internal;

// Limit:
// C = norm(pB - pA) - L
// u = (pB - pA) / norm(pB - pA)
// Cdot = dot(u, vB + cross(wB, rB) - vA - cross(wA, rA))
// J = [-u -cross(rA, u) u cross(rB, u)]
// K = J * invM * JT
//   = invMassA + invIA * cross(rA, u)^2 + invMassB + invIB * cross(rB, u)^2
		
/**
 * A rope joint enforces a maximum distance between two points
 * on two bodies. It has no other effect.
 * Warning: if you attempt to change the maximum length during
 * the simulation you will get some non-physical behavior.
 * A model that would allow you to dynamically modify the length
 * would have some sponginess, so I chose not to implement it
 * that way. See b2DistanceJoint if you want to dynamically
 * control length.
 * @see b2RopeJointDef
 */
public class b2RopeJoint extends b2Joint
{
	
	private var m_localAnchorA:b2Vec2;
	private var m_localAnchorB:b2Vec2;
	
	private var m_maxLength:Number;
	private var m_length:Number;
	
	// Jacobian info
	private var m_u:b2Vec2, m_rA:b2Vec2, m_rB:b2Vec2;
	
	// Effective mass
	private var m_mass:Number;
	
	// Impulses for accumulation/warm starting.
	private var m_impulse:Number;
	
	private var m_state:int;
	
	public function b2RopeJoint(def:b2RopeJointDef)
	{
		super(def);
		m_localAnchorA = def.localAnchorA;
		m_localAnchorB = def.localAnchorB;
		
		m_maxLength = def.maxLength;
		
		m_mass = 0.0;
		m_impulse = 0.0;
		m_state = b2Joint.e_inactiveLimit;
		m_length = 0.0;
	}
	
	b2internal override function InitVelocityConstraints(step:b2TimeStep):void
	{
		var bA:b2Body = m_bodyA;
		var bB:b2Body = m_bodyB;
		
		m_rA = b2Math.MulMV(bA.GetTransform().R, b2Math.SubtractVV(m_localAnchorA, bA.GetLocalCenter()));
		m_rB = b2Math.MulMV(bB.GetTransform().R, b2Math.SubtractVV(m_localAnchorB, bB.GetLocalCenter()));
		
		// Rope axis
		m_u = b2Math.SubtractVV(b2Math.SubtractVV(b2Math.AddVV(bB.m_sweep.c, m_rB), bA.m_sweep.c), m_rA);
		
		m_length = m_u.Length();
		
		var C:Number = m_length - m_maxLength;
		if (C > 0.0)
		{
			m_state = e_atUpperLimit;
		}
		else
		{
			m_state = e_inactiveLimit;
		}
		
		if (m_length > b2Settings.b2_linearSlop)
		{
			m_u.Multiply(1.0 / m_length);
		}
		else
		{
			m_u.SetZero();
			m_mass = 0.0;
			m_impulse = 0.0;
			return;
		}
		
		// Compute effective mass.
		var crA:Number = b2Math.CrossVV(m_rA, m_u);
		var crB:Number = b2Math.CrossVV(m_rB, m_u);
		var invMass:Number = bA.m_invMass + bA.m_invI * crA * crA + bB.m_invMass + bB.m_invI * crB * crB;
		
		m_mass = invMass != 0.0 ? 1.0 / invMass : 0.0;
		
		if (step.warmStarting)
		{
			// Scale the impulse to support a variable time step.
			m_impulse *= step.dtRatio;
			
			var P:b2Vec2 = b2Math.MulFV(m_impulse, m_u);
			bA.m_linearVelocity.Subtract(b2Math.MulFV(bA.m_invMass, P));
			bA.m_angularVelocity -= bA.m_invI * b2Math.CrossVV(m_rA, P);
			bB.m_linearVelocity.Add(b2Math.MulFV(bB.m_invMass, P));
			bB.m_angularVelocity += bB.m_invI * b2Math.CrossVV(m_rB, P);
		}
		else
		{
			m_impulse = 0.0;
		}
	}
	
	b2internal override function SolveVelocityConstraints(step:b2TimeStep):void
	{
		//B2_NOT_USED(step);
		
		var bA:b2Body = m_bodyA;
		var bB:b2Body = m_bodyB;
		
		// Cdot = dot(u, v + cross(w, r))
		var vA:b2Vec2 = b2Math.AddVV(bA.m_linearVelocity, b2Math.CrossFV(bA.m_angularVelocity, m_rA));
		var vB:b2Vec2 = b2Math.AddVV(bB.m_linearVelocity, b2Math.CrossFV(bB.m_angularVelocity, m_rB));
		var C:Number = m_length - m_maxLength;
		var Cdot:Number = b2Math.Dot(m_u, b2Math.SubtractVV(vB, vA));
		
		// Predictive constraint.
		if (C < 0.0)
		{
			Cdot += step.inv_dt * C;
		}
		
		var impulse:Number = -m_mass * Cdot;
		var oldImpulse:Number = m_impulse;
		m_impulse = b2Math.Min(0.0, m_impulse + impulse);
		impulse = m_impulse - oldImpulse;
		
		var P:b2Vec2 = b2Math.MulFV(impulse, m_u);
		bA.m_linearVelocity.Subtract(b2Math.MulFV(bA.m_invMass, P));
		bA.m_angularVelocity -= bA.m_invI * b2Math.CrossVV(m_rA, P);
		bB.m_linearVelocity.Add(b2Math.MulFV(bB.m_invMass, P));
		bB.m_angularVelocity += bB.m_invI * b2Math.CrossVV(m_rB, P);
	}
	
	b2internal override function SolvePositionConstraints(baumgarte:Number):Boolean
	{
		//B2_NOT_USED(baumgarte);
		
		var bA:b2Body = m_bodyA;
		var bB:b2Body = m_bodyB;
		
		var rA:b2Vec2 = b2Math.MulMV(bA.GetTransform().R, b2Math.SubtractVV(m_localAnchorA, bA.GetLocalCenter()));
		var rB:b2Vec2 = b2Math.MulMV(bB.GetTransform().R, b2Math.SubtractVV(m_localAnchorB, bB.GetLocalCenter()));
		
		var u:b2Vec2 = b2Math.AddVV(bB.m_sweep.c, rB);
		u.Subtract(bA.m_sweep.c);
		u.Subtract(rA);
		
		var length:Number = u.Normalize();
		var C:Number = length - m_maxLength;
		
		C = b2Math.Clamp(C, 0.0, b2Settings.b2_maxLinearCorrection);
		
		var impulse:Number = -m_mass * C;
		var P:b2Vec2 = b2Math.MulFV(impulse, u);
		
		bA.m_sweep.c.Subtract(b2Math.MulFV(bA.m_invMass, P));
		bA.m_sweep.a -= bA.m_invI * b2Math.CrossVV(rA, P);
		bB.m_sweep.c.Add(b2Math.MulFV(bB.m_invMass, P));
		bB.m_sweep.a += bB.m_invI * b2Math.CrossVV(rB, P);
		
		bA.SynchronizeTransform();
		bB.SynchronizeTransform();
		
		return length - m_maxLength < b2Settings.b2_linearSlop;
	}
	
	override public function GetAnchorA():b2Vec2
	{
		return m_bodyA.GetWorldPoint(m_localAnchorA);
	}
	
	override public function GetAnchorB():b2Vec2
	{
		return m_bodyB.GetWorldPoint(m_localAnchorB);
	}
	
	override public function GetReactionForce(inv_dt:Number):b2Vec2
	{
		var F:b2Vec2 = b2Math.MulFV(inv_dt * m_impulse, m_u);
		return F;
	}
	
	override public function GetReactionTorque(inv_dt:Number):Number
	{
		//B2_NOT_USED(inv_dt);
		return 0.0;
	}

	/**
	 * Get the maximum length of the rope.
	 */
	public function GetMaxLength():Number
	{
		return m_maxLength;
	}
	
	public function GetLimitState():int
	{
		return m_state;
	}

}
}